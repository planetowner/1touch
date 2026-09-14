import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';
import 'package:onetouch/data/standings/api_standing_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/data/standings/standing_repository_provider.dart'
    as standing_options;
import 'package:onetouch/data/standings/xg_standing_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/features/StandingFeatures.dart';
import 'package:onetouch/features/knockout_bracket.dart';

class StandingTab extends StatefulWidget {
  final Map<String, dynamic>? team;
  final StandingRepository? regularStandingRepository;

  const StandingTab({
    super.key,
    required this.team,
    this.regularStandingRepository,
  });

  @override
  State<StandingTab> createState() => _StandingTabState();
}

class _StandingTabState extends State<StandingTab> {
  // xG standings are only available for Big 5 leagues
  static const _big5LeagueIds = {8, 82, 301, 384, 564};

  int selectedLeagueId = 8;
  int selectedSeasonId = 23614;
  bool isScrolledToEnd = false;

  final ScrollController _horizontalScrollController = ScrollController();

  // Two separate data sources — different shapes, different endpoints.
  List<Map<String, dynamic>> standings = [];
  List<Map<String, dynamic>> xgStandings = [];
  bool _isStandingLoading = true;
  Object? _standingLoadError;
  int _standingRequestId = 0;

  int? currentTeamId;
  List<int> _validLeagueIds = [];

  StandingView _selectedView = StandingView.standing;

  bool get _xgAvailable => _big5LeagueIds.contains(selectedLeagueId);

  StandingRepository get _regularStandingRepository =>
      widget.regularStandingRepository ?? apiStandingRepository;

  List<Fixture> get _selectedKnockoutFixtures => fixtureRepository
      .forCompetition(
        selectedLeagueId,
        seasonId: selectedSeasonId,
        competitionType: CompetitionType.europe,
      )
      .where((fixture) => knockoutRoundFromName(fixture.roundName) != null)
      .toList();

  bool get _showKnockoutBracket =>
      hasEuropeanKnockoutStage(_selectedKnockoutFixtures);

  @override
  void initState() {
    super.initState();

    _setDefaultLeagueAndSeason();
    _loadXgData(updateState: false);
    _startStandingLoad(updateState: false);

    _horizontalScrollController.addListener(_handleHorizontalScroll);
  }

  @override
  void didUpdateWidget(StandingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so redo the team-based setup
    // instead of only doing it once in initState.
    if (widget.team?['id'] != oldWidget.team?['id'] ||
        widget.regularStandingRepository !=
            oldWidget.regularStandingRepository) {
      _setDefaultLeagueAndSeason();
      _loadXgData();
      _startStandingLoad();
    }
  }

  void _setDefaultLeagueAndSeason() {
    currentTeamId = widget.team?['id'] as int?;
    final fixtures = currentTeamId != null
        ? fixtureRepository.forTeam(currentTeamId!)
        : const <Fixture>[];

    _validLeagueIds = fixtures
        .map((f) => f.competitionId)
        .toSet()
        .where(
          (id) =>
              standing_options.standingRepository.forCompetition(id).isNotEmpty,
        )
        .toList();

    final leagueId = _validLeagueIds.isNotEmpty
        ? _validLeagueIds.first
        : competitionRepository.allCompetitions.first.competitionId;

    final seasonId = (seasonRepository.currentForCompetition(leagueId) ??
            seasonRepository.allSeasons.first)
        .seasonId;

    selectedLeagueId = leagueId;
    selectedSeasonId = seasonId;
  }

  @override
  void dispose() {
    _horizontalScrollController.removeListener(_handleHorizontalScroll);
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _handleHorizontalScroll() {
    final controller = _horizontalScrollController;
    if (!controller.hasClients) return;

    final atEnd = controller.offset >= controller.position.maxScrollExtent - 4;
    if (isScrolledToEnd != atEnd) {
      setState(() => isScrolledToEnd = atEnd);
    }
  }

  void _loadXgData({bool updateState = true}) {
    //   xG standings (Big 5 only — different source/endpoint)
    List<Map<String, dynamic>> newXg = [];
    if (_xgAvailable) {
      final xgRows = xgStandingRepository.forCompetition(selectedLeagueId);
      newXg = xgRows.map((x) {
        final team = teamRepository.findByIdOrUnknown(x.teamId);
        return {
          'rank': x.position,
          'teamId': x.teamId,
          'team': team.shortCode ?? team.name,
          'logo': team.imagePath ?? '',
          'mp': x.matchesPlayed,
          'w': x.won,
          'd': x.draw,
          'l': x.lost,
          'xg': x.xg,
          'xga': x.xga,
          'xpts': x.xpts,
        };
      }).toList();
    }

    if (updateState) {
      setState(() => xgStandings = newXg);
    } else {
      xgStandings = newXg;
    }
  }

  List<Map<String, dynamic>> _mapStandingRows(
    List<Standing> rows,
  ) {
    return rows
        .map(
          (standing) => {
            'rank': standing.position,
            'rankDelta': standing.rankDelta,
            'teamId': standing.teamId,
            'team': standing.teamName ?? 'Unknown Team',
            'logo': standing.teamLogo ?? '',
            'mp': standing.matchesPlayed,
            'w': standing.won,
            'd': standing.draw,
            'l': standing.lost,
            'gf': standing.goalsFor,
            'ga': standing.goalsAgainst,
            'pts': standing.points,
            'last5': standing.last5Form,
          },
        )
        .toList(growable: false);
  }

  void _startStandingLoad({bool updateState = true}) {
    final competitionId = selectedLeagueId;
    final seasonId = selectedSeasonId;
    final requestId = ++_standingRequestId;
    final cached = _regularStandingRepository.cachedForCompetition(
      competitionId,
      seasonId: seasonId,
    );

    void applyInitialState() {
      standings = cached == null ? const [] : _mapStandingRows(cached);
      _isStandingLoading = cached == null;
      _standingLoadError = null;
    }

    if (updateState) {
      setState(applyInitialState);
    } else {
      applyInitialState();
    }

    _loadStandings(
      competitionId: competitionId,
      seasonId: seasonId,
      requestId: requestId,
    );
  }

  Future<void> _loadStandings({
    required int competitionId,
    required int seasonId,
    required int requestId,
  }) async {
    try {
      final rows = await _regularStandingRepository.loadForCompetition(
        competitionId,
        seasonId: seasonId,
      );
      if (!mounted ||
          requestId != _standingRequestId ||
          competitionId != selectedLeagueId ||
          seasonId != selectedSeasonId) {
        return;
      }
      setState(() {
        standings = _mapStandingRows(rows);
        _isStandingLoading = false;
        _standingLoadError = null;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _standingRequestId ||
          competitionId != selectedLeagueId ||
          seasonId != selectedSeasonId) {
        return;
      }
      setState(() {
        _isStandingLoading = false;
        _standingLoadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  key: const ValueKey('standing-filter-row'),
                  children: [
                    Expanded(child: _buildLeagueDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSeasonDropdown()),
                  ],
                ),
              ),
              if (_showKnockoutBracket)
                KnockoutBracket(
                  fixtures: _selectedKnockoutFixtures,
                  currentTeamId: currentTeamId,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: StandingViewToggle(
                        selectedView: _selectedView,
                        availableViews: _availableViews,
                        onChanged: _changeStandingView,
                      ),
                    ),
                    _buildSelectedTable(),
                    StandingsLegend(leagueId: selectedLeagueId),
                  ],
                ),
              const SizedBox(height: 144),
            ],
          ),
        ),
      ],
    );
  }

  void _changeStandingView(StandingView view) {
    if (!_availableViews.contains(view) || _selectedView == view) return;
    setState(() => _selectedView = view);
  }

  // Which views are usable for the currently selected league.
  // xG TABLE is hidden entirely for non-Big-5 leagues.
  List<StandingView> get _availableViews => [
        StandingView.standing,
        if (_xgAvailable) StandingView.xgTable,
      ];

  Widget _buildSelectedTable() {
    switch (_selectedView) {
      case StandingView.standing:
        if (_isStandingLoading && standings.isEmpty) {
          return const Padding(
            key: ValueKey('standing-loading'),
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_standingLoadError != null && standings.isEmpty) {
          return Padding(
            key: const ValueKey('standing-error'),
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  const Text('Unable to load standings'),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('standing-retry'),
                    onPressed: _startStandingLoad,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (standings.isEmpty) {
          return const Padding(
            key: ValueKey('standing-empty'),
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No standings available')),
          );
        }
        return StandingTable(
          standings: standings,
          currentTeamId: currentTeamId,
          leagueId: selectedLeagueId,
          horizontalScrollController: _horizontalScrollController,
          isScrolledToEnd: isScrolledToEnd,
        );
      case StandingView.xgTable:
        return XgTable(
          standings: xgStandings,
          currentTeamId: currentTeamId,
          leagueId: selectedLeagueId,
          horizontalScrollController: _horizontalScrollController,
          isScrolledToEnd: isScrolledToEnd,
        );
    }
  }

  Widget _buildLeagueDropdown() {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final availableLeagues = _validLeagueIds.isNotEmpty
        ? competitionRepository.allCompetitions
            .where((l) => _validLeagueIds.contains(l.competitionId))
            .toList()
        : competitionRepository.allCompetitions;

    return Container(
      key: const ValueKey('standing-league-filter-shell'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: appColors.subtleBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: const ValueKey('standing-league-filter'),
          value: selectedLeagueId,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurface),
          dropdownColor: appColors.cardBackground,
          style: Body2_b.style.copyWith(color: colors.onSurface),
          onChanged: (val) {
            if (val == null) return;
            final season = seasonRepository.currentForCompetition(val) ??
                seasonRepository.forCompetition(val).first;
            setState(() {
              selectedLeagueId = val;
              selectedSeasonId = season.seasonId;
              // If user was viewing xG and new league isn't Big 5, fall back
              if (!_xgAvailable && _selectedView == StandingView.xgTable) {
                _selectedView = StandingView.standing;
              }
            });
            _loadXgData();
            _startStandingLoad();
          },
          items: availableLeagues
              .map(
                (l) => DropdownMenuItem(
                  value: l.competitionId,
                  child: Text(
                    l.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body2_b.style.copyWith(color: colors.onSurface),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSeasonDropdown() {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final seasons = seasonRepository.forCompetition(selectedLeagueId);

    return Container(
      key: const ValueKey('standing-season-filter-shell'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: appColors.subtleBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: const ValueKey('standing-season-filter'),
          value: selectedSeasonId,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.onSurface),
          dropdownColor: appColors.cardBackground,
          style: Body2_b.style.copyWith(color: colors.onSurface),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              selectedSeasonId = val;
            });
            _loadXgData();
            _startStandingLoad();
          },
          items: seasons
              .map(
                (s) => DropdownMenuItem(
                  value: s.seasonId,
                  child: Text(
                    s.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body2_b.style.copyWith(color: colors.onSurface),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
