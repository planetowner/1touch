import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';
import 'package:onetouch/data/standings/api_standing_repository_provider.dart';
import 'package:onetouch/data/standings/api_xg_standing_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/data/standings/standing_repository_provider.dart'
    as standing_options;
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/features/StandingFeatures.dart';
import 'package:onetouch/features/knockout_bracket.dart';

class StandingTab extends StatefulWidget {
  final Map<String, dynamic>? team;
  final StandingRepository? regularStandingRepository;
  final XgStandingRepository? xgStandingRepository;
  final int? requestedCompetitionId;
  final int selectionRequestId;

  const StandingTab({
    super.key,
    required this.team,
    this.regularStandingRepository,
    this.xgStandingRepository,
    this.requestedCompetitionId,
    this.selectionRequestId = 0,
  });

  @override
  State<StandingTab> createState() => _StandingTabState();
}

class _StandingTabState extends State<StandingTab> {
  // xG standings are only available for Big 5 leagues
  static const _big5LeagueIds = {8, 82, 301, 384, 564};

  // TODO(standing-seasons): Replace these verified current-season options
  // with the shared backend season-options response when that endpoint is
  // available. Keeping them local prevents a Standing-only workaround from
  // changing season selection in Squad, Analysis, or other features.
  static const _currentBig5Seasons = <int, _StandingSeasonOption>{
    8: _StandingSeasonOption(28083, '2026/2027'),
    82: _StandingSeasonOption(28321, '2026/2027'),
    301: _StandingSeasonOption(28082, '2026/2027'),
    384: _StandingSeasonOption(27895, '2026/2027'),
    564: _StandingSeasonOption(27965, '2026/2027'),
  };

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
  bool _isXgLoading = false;
  Object? _xgLoadError;
  int _xgRequestId = 0;

  int? currentTeamId;
  List<int> _validLeagueIds = [];

  StandingView _selectedView = StandingView.standing;

  bool get _xgAvailable => _big5LeagueIds.contains(selectedLeagueId);
  bool get _hasStandingContext => _validLeagueIds.isNotEmpty;

  StandingRepository get _regularStandingRepository =>
      widget.regularStandingRepository ?? apiStandingRepository;

  XgStandingRepository get _xgStandingRepository =>
      widget.xgStandingRepository ?? apiXgStandingRepository;

  List<Fixture> get _selectedKnockoutFixtures => fixtureRepository
      .forCompetition(
        selectedLeagueId,
        seasonId: selectedSeasonId,
        competitionType: CompetitionType.europe,
      )
      .where((fixture) => knockoutRoundFromName(fixture.roundName) != null)
      .toList();

  bool get _knockoutBracketAvailable =>
      hasEuropeanKnockoutStage(_selectedKnockoutFixtures);

  StandingView get _defaultView =>
      _knockoutBracketAvailable ? StandingView.bracket : StandingView.standing;

  StandingView _viewAfterSelectionChange(StandingView currentView) {
    if (currentView == StandingView.xgTable && _xgAvailable) {
      return currentView;
    }
    if (currentView == StandingView.bracket && _knockoutBracketAvailable) {
      return currentView;
    }
    return _defaultView;
  }

  @override
  void initState() {
    super.initState();

    _setDefaultLeagueAndSeason();
    _applyRequestedCompetition(widget.requestedCompetitionId);
    _startStandingLoad(updateState: false);

    _horizontalScrollController.addListener(_handleHorizontalScroll);
  }

  @override
  void didUpdateWidget(StandingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so redo the team-based setup
    // instead of only doing it once in initState.
    final dependenciesChanged = widget.team?['id'] != oldWidget.team?['id'] ||
        widget.regularStandingRepository !=
            oldWidget.regularStandingRepository ||
        widget.xgStandingRepository != oldWidget.xgStandingRepository;
    if (dependenciesChanged) {
      _setDefaultLeagueAndSeason();
      if (_selectedView == StandingView.xgTable && _xgAvailable) {
        _startXgLoad();
      } else {
        _resetXgState();
      }
      _startStandingLoad();
      return;
    }

    if (widget.selectionRequestId != oldWidget.selectionRequestId) {
      final competitionId = widget.requestedCompetitionId;
      if (competitionId != null) {
        _selectOverviewCompetition(competitionId);
      }
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

    final seasonId = _defaultSeasonForCompetition(leagueId).seasonId;

    selectedLeagueId = leagueId;
    selectedSeasonId = seasonId;
    _selectedView = _defaultView;
  }

  bool _applyRequestedCompetition(int? competitionId) {
    if (competitionId == null || !_validLeagueIds.contains(competitionId)) {
      return false;
    }
    final seasons = _seasonOptionsForCompetition(competitionId);
    if (seasons.isEmpty) return false;

    final season = _defaultSeasonForCompetition(competitionId);
    selectedLeagueId = competitionId;
    selectedSeasonId = season.seasonId;
    _selectedView = _defaultView;
    return true;
  }

  void _selectOverviewCompetition(int competitionId) {
    if (!_validLeagueIds.contains(competitionId) ||
        _seasonOptionsForCompetition(competitionId).isEmpty) {
      return;
    }

    setState(() => _applyRequestedCompetition(competitionId));
    _resetXgState();
    _startStandingLoad();
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

  List<Map<String, dynamic>> _mapXgStandingRows(
    List<XgStanding> rows,
  ) {
    return rows
        .map(
          (standing) => {
            'rank': standing.position,
            'teamId': standing.teamId,
            'team': standing.teamName ?? 'Unknown Team',
            'logo': standing.teamLogo ?? '',
            'mp': standing.matchesPlayed,
            'xg': standing.xg,
            'xga': standing.xga,
            'xpts': standing.xpts,
          },
        )
        .toList(growable: false);
  }

  void _resetXgState() {
    _xgRequestId++;
    xgStandings = const [];
    _isXgLoading = false;
    _xgLoadError = null;
  }

  void _startXgLoad({bool updateState = true}) {
    if (!_hasStandingContext || !_xgAvailable) {
      if (updateState) {
        setState(_resetXgState);
      } else {
        _resetXgState();
      }
      return;
    }

    final competitionId = selectedLeagueId;
    final seasonId = selectedSeasonId;
    final requestId = ++_xgRequestId;
    final cached = _xgStandingRepository.cachedForCompetition(
      competitionId,
      seasonId: seasonId,
    );

    void applyInitialState() {
      xgStandings = cached == null ? const [] : _mapXgStandingRows(cached);
      _isXgLoading = cached == null;
      _xgLoadError = null;
    }

    if (updateState) {
      setState(applyInitialState);
    } else {
      applyInitialState();
    }

    _loadXgStandings(
      competitionId: competitionId,
      seasonId: seasonId,
      requestId: requestId,
    );
  }

  Future<void> _loadXgStandings({
    required int competitionId,
    required int seasonId,
    required int requestId,
  }) async {
    try {
      final rows = await _xgStandingRepository.loadForCompetition(
        competitionId,
        seasonId: seasonId,
      );
      if (!mounted ||
          requestId != _xgRequestId ||
          competitionId != selectedLeagueId ||
          seasonId != selectedSeasonId) {
        return;
      }
      setState(() {
        xgStandings = _mapXgStandingRows(rows);
        _isXgLoading = false;
        _xgLoadError = null;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _xgRequestId ||
          competitionId != selectedLeagueId ||
          seasonId != selectedSeasonId) {
        return;
      }
      setState(() {
        _isXgLoading = false;
        _xgLoadError = error;
      });
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
    if (!_hasStandingContext) {
      final requestId = ++_standingRequestId;

      void applyUnavailableState() {
        if (requestId != _standingRequestId) return;
        standings = const [];
        _isStandingLoading = false;
        _standingLoadError = null;
      }

      if (updateState) {
        setState(applyUnavailableState);
      } else {
        applyUnavailableState();
      }
      return;
    }

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
    if (!_hasStandingContext) {
      return const Center(
        child: Text(
          'No standings available',
          key: ValueKey('standing-unavailable'),
        ),
      );
    }

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: StandingViewToggle(
                      selectedView: _selectedView,
                      availableViews: _availableViews,
                      displayedViews: _displayedViews,
                      onChanged: _changeStandingView,
                    ),
                  ),
                  _buildSelectedContent(),
                  if (_selectedView != StandingView.bracket)
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
    if (view == StandingView.xgTable) {
      _startXgLoad();
    }
  }

  // Which views are usable for the currently selected competition.
  List<StandingView> get _availableViews => [
        StandingView.standing,
        if (_xgAvailable) StandingView.xgTable,
        if (_knockoutBracketAvailable) StandingView.bracket,
      ];

  // Preserve the established two-segment control: European knockout seasons
  // swap BRACKET into the second slot instead of changing the control's shape.
  List<StandingView> get _displayedViews => [
        StandingView.standing,
        if (_knockoutBracketAvailable)
          StandingView.bracket
        else
          StandingView.xgTable,
      ];

  Widget _buildSelectedContent() {
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
        if (_isXgLoading && xgStandings.isEmpty) {
          return const Padding(
            key: ValueKey('xg-standing-loading'),
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_xgLoadError != null && xgStandings.isEmpty) {
          return Padding(
            key: const ValueKey('xg-standing-error'),
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  const Text('Unable to load xG standings'),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('xg-standing-retry'),
                    onPressed: _startXgLoad,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (xgStandings.isEmpty) {
          return const Padding(
            key: ValueKey('xg-standing-empty'),
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('No xG standings available')),
          );
        }
        return XgTable(
          standings: xgStandings,
          currentTeamId: currentTeamId,
          leagueId: selectedLeagueId,
          horizontalScrollController: _horizontalScrollController,
          isScrolledToEnd: isScrolledToEnd,
        );
      case StandingView.bracket:
        return KnockoutBracket(
          fixtures: _selectedKnockoutFixtures,
          currentTeamId: currentTeamId,
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
            final season = _defaultSeasonForCompetition(val);
            final previousView = _selectedView;
            setState(() {
              selectedLeagueId = val;
              selectedSeasonId = season.seasonId;
              _selectedView = _viewAfterSelectionChange(previousView);
            });
            if (_selectedView == StandingView.xgTable && _xgAvailable) {
              _startXgLoad();
            } else {
              _resetXgState();
            }
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
    final seasons = _seasonOptionsForCompetition(selectedLeagueId);

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
            final previousView = _selectedView;
            setState(() {
              selectedSeasonId = val;
              _selectedView = _viewAfterSelectionChange(previousView);
            });
            if (_selectedView == StandingView.xgTable) {
              _startXgLoad();
            } else {
              _resetXgState();
            }
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

  _StandingSeasonOption _defaultSeasonForCompetition(int competitionId) {
    final current = _currentBig5Seasons[competitionId];
    if (current != null) return current;

    final catalogCurrent =
        seasonRepository.currentForCompetition(competitionId);
    if (catalogCurrent != null) {
      return _StandingSeasonOption(
          catalogCurrent.seasonId, catalogCurrent.name);
    }

    final options = _seasonOptionsForCompetition(competitionId);
    if (options.isNotEmpty) return options.first;

    final fallback = seasonRepository.allSeasons.first;
    return _StandingSeasonOption(fallback.seasonId, fallback.name);
  }

  List<_StandingSeasonOption> _seasonOptionsForCompetition(int competitionId) {
    final current = _currentBig5Seasons[competitionId];
    final options = <_StandingSeasonOption>[
      if (current != null) current,
      ...seasonRepository.forCompetition(competitionId).map(
            (season) => _StandingSeasonOption(season.seasonId, season.name),
          ),
    ];
    final seen = <int>{};
    return List.unmodifiable(
      options.where((option) => seen.add(option.seasonId)),
    );
  }
}

class _StandingSeasonOption {
  const _StandingSeasonOption(this.seasonId, this.name);

  final int seasonId;
  final String name;
}
