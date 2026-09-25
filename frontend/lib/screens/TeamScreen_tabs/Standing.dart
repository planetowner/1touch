import 'package:flutter/material.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';
import 'package:onetouch/data/standings/api_standing_repository_provider.dart';
import 'package:onetouch/data/standings/api_xg_standing_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/features/StandingFeatures.dart';
import 'package:onetouch/features/api_knockout_bracket.dart';
import 'package:onetouch/data/competitions/tournament_bracket_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class StandingTab extends StatefulWidget {
  final Map<String, dynamic>? team;
  final StandingRepository? regularStandingRepository;
  final XgStandingRepository? xgStandingRepository;
  final int? requestedCompetitionId;
  final int selectionRequestId;
  final ValueChanged<bool>? onBracketInteractionChanged;

  const StandingTab({
    super.key,
    required this.team,
    this.regularStandingRepository,
    this.xgStandingRepository,
    this.requestedCompetitionId,
    this.selectionRequestId = 0,
    this.onBracketInteractionChanged,
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
  bool _isBracketInteracting = false;

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

  bool get _knockoutBracketAvailable =>
      TournamentBracketRepository.supportedCompetitions
          .contains(selectedLeagueId) &&
      (seasonRepository
                  .findById(selectedSeasonId)
                  ?.name
                  .compareTo('2024/2025') ??
              -1) >=
          0;

  StandingView get _defaultView => StandingView.standing;

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
    _validLeagueIds = footballCatalog.memberships
        .where((m) => m.teamId == currentTeamId)
        .map((m) => m.competitionId)
        .toSet()
        .toList()
      ..sort((a, b) => (_big5LeagueIds.contains(a) ? 0 : 1)
          .compareTo(_big5LeagueIds.contains(b) ? 0 : 1));
    if (_validLeagueIds.isEmpty) return;
    final leagueId = _validLeagueIds.first;

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
      return Center(
        child: Text(
          tr(context, 'No standings available'),
          key: ValueKey('standing-unavailable'),
        ),
      );
    }

    return CustomScrollView(
      physics:
          _isBracketInteracting ? const NeverScrollableScrollPhysics() : null,
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
                  Text(tr(context, 'Unable to load standings')),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('standing-retry'),
                    onPressed: _startStandingLoad,
                    child: Text(tr(context, 'Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        if (standings.isEmpty) {
          return Padding(
            key: ValueKey('standing-empty'),
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text(tr(context, 'No standings available'))),
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
                  Text(tr(context, 'Unable to load xG standings')),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('xg-standing-retry'),
                    onPressed: _startXgLoad,
                    child: Text(tr(context, 'Retry')),
                  ),
                ],
              ),
            ),
          );
        }
        if (xgStandings.isEmpty) {
          return Padding(
            key: ValueKey('xg-standing-empty'),
            padding: EdgeInsets.symmetric(vertical: 48),
            child:
                Center(child: Text(tr(context, 'No xG standings available'))),
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
        return ApiKnockoutBracket(
          competitionId: selectedLeagueId,
          seasonId: selectedSeasonId,
          currentTeamId: currentTeamId,
          onInteractionChanged: _handleBracketInteractionChanged,
        );
    }
  }

  void _handleBracketInteractionChanged(bool isInteracting) {
    if (_isBracketInteracting == isInteracting) return;
    setState(() => _isBracketInteracting = isInteracting);
    widget.onBracketInteractionChanged?.call(isInteracting);
  }

  Widget _buildLeagueDropdown() {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final availableLeagues = _validLeagueIds.isNotEmpty
        ? competitionRepository.allCompetitions
            .where((l) => _validLeagueIds.contains(l.competitionId))
            .toList()
        : competitionRepository.allCompetitions;

    return AppDropdown<int>(
      key: const ValueKey('standing-league-filter-shell'),
      triggerKey: const ValueKey('standing-league-filter'),
      value: selectedLeagueId,
      backgroundColor: appColors.subtleBackground,
      foregroundColor: colors.onSurface,
      textStyle: Body2_b.style,
      onChanged: (val) {
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
      options: availableLeagues
          .map(
            (league) => AppDropdownOption<int>(
              value: league.competitionId,
              label: competitionNameLabel(
                context,
                league.competitionId,
                league.name,
              ).toUpperCase(),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSeasonDropdown() {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final seasons = _seasonOptionsForCompetition(selectedLeagueId);

    return AppDropdown<int>(
      key: const ValueKey('standing-season-filter-shell'),
      triggerKey: const ValueKey('standing-season-filter'),
      value: selectedSeasonId,
      backgroundColor: appColors.subtleBackground,
      foregroundColor: colors.onSurface,
      textStyle: Body2_b.style,
      onChanged: (val) {
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
      options: seasons
          .map(
            (season) => AppDropdownOption<int>(
              value: season.seasonId,
              label: season.name.toUpperCase(),
            ),
          )
          .toList(),
    );
  }

  _StandingSeasonOption _defaultSeasonForCompetition(int competitionId) {
    final catalogCurrent =
        seasonRepository.currentForCompetition(competitionId);
    if (catalogCurrent != null) {
      return _StandingSeasonOption(
          catalogCurrent.seasonId, catalogCurrent.name);
    }

    final options = _seasonOptionsForCompetition(competitionId);
    if (options.isNotEmpty) return options.first;

    throw StateError('No seasons for competition $competitionId');
  }

  List<_StandingSeasonOption> _seasonOptionsForCompetition(int competitionId) {
    final options = <_StandingSeasonOption>[
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
