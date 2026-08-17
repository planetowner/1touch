import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/features/StandingFeatures.dart';
import 'package:onetouch/features/knockout_bracket.dart';

class StandingTab extends StatefulWidget {
  final Map<String, dynamic>? team;

  const StandingTab({super.key, required this.team});

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

  int? currentTeamId;
  List<int> _validLeagueIds = [];

  StandingView _selectedView = StandingView.standing;

  bool get _xgAvailable => _big5LeagueIds.contains(selectedLeagueId);

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
    _loadData();

    _horizontalScrollController.addListener(_handleHorizontalScroll);
  }

  @override
  void didUpdateWidget(StandingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so redo the team-based setup
    // instead of only doing it once in initState.
    if (widget.team?['id'] != oldWidget.team?['id']) {
      _setDefaultLeagueAndSeason();
      _loadData();
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
        .where((id) => standingsByCompetition(id).isNotEmpty)
        .toList();

    final leagueId = _validLeagueIds.isNotEmpty
        ? _validLeagueIds.first
        : mockCompetitions.first.competitionId;

    final seasonId = mockSeasons
        .firstWhere(
          (s) => s.competitionId == leagueId && s.isCurrent,
          orElse: () => mockSeasons.first,
        )
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

  void _loadData() {
    // ── Standings (always) ───────────────────────────────────────────
    final standingRows = standingsByCompetition(selectedLeagueId);
    final newStandings = standingRows.map((s) {
      final team = teamRepository.findByIdOrUnknown(s.teamId);
      return {
        'rank': s.position,
        'teamId': s.teamId,
        'team': team.shortCode ?? team.name,
        'logo': team.imagePath ?? '',
        'mp': s.matchesPlayed,
        'w': s.won,
        'd': s.draw,
        'l': s.lost,
        'gf': s.goalsFor,
        'ga': s.goalsAgainst,
        'pts': s.points,
        'last5': s.last5Form,
      };
    }).toList();

    // ── xG standings (Big 5 only — different source/endpoint) ───────
    List<Map<String, dynamic>> newXg = [];
    if (_xgAvailable) {
      final xgRows = xgStandingsByLeague(selectedLeagueId);
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

    setState(() {
      standings = newStandings;
      xgStandings = newXg;
    });
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
        ? mockCompetitions
            .where((l) => _validLeagueIds.contains(l.competitionId))
            .toList()
        : mockCompetitions;

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
            final season = mockSeasons.firstWhere(
              (s) => s.competitionId == val && s.isCurrent,
              orElse: () =>
                  mockSeasons.firstWhere((s) => s.competitionId == val),
            );
            setState(() {
              selectedLeagueId = val;
              selectedSeasonId = season.seasonId;
              // If user was viewing xG and new league isn't Big 5, fall back
              if (!_xgAvailable && _selectedView == StandingView.xgTable) {
                _selectedView = StandingView.standing;
              }
            });
            _loadData();
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
    final seasons =
        mockSeasons.where((s) => s.competitionId == selectedLeagueId).toList();

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
            _loadData();
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
