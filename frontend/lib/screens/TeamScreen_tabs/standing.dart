import 'package:onetouch/core/page_refresh.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/season_label.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';
import 'package:onetouch/data/standings/api_standing_repository_provider.dart';
import 'package:onetouch/data/standings/api_xg_standing_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/features/standing_features.dart';
import 'package:onetouch/features/competition/competition_label.dart';
import 'package:onetouch/features/api_knockout_bracket.dart';
import 'package:onetouch/data/competitions/tournament_bracket_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class StandingTab extends StatefulWidget {
  final TeamOverview? team;
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

class _StandingTabState extends State<StandingTab>
    with PageRefreshParticipant<StandingTab> {
  @override
  Future<void> refreshPage() async {
    if (!_hasStandingContext) return;
    await Future.wait([
      _loadStandings(
          competitionId: selectedLeagueId,
          seasonId: selectedSeasonId,
          requestId: ++_standingRequestId,
          forceRefresh: true),
      if (_selectedView == StandingView.xgTable && _xgAvailable)
        _loadXgStandings(
            competitionId: selectedLeagueId,
            seasonId: selectedSeasonId,
            requestId: ++_xgRequestId,
            forceRefresh: true),
    ]);
  }

  // xG standings are only available for Big 5 leagues
  static const _big5LeagueIds = {8, 82, 301, 384, 564};

  int selectedLeagueId = 8;
  int selectedSeasonId = 23614;
  bool isScrolledToEnd = false;
  bool _isBracketInteracting = false;

  final ScrollController _horizontalScrollController = ScrollController();

  // Two separate data sources — different shapes, different endpoints.
  List<Standing> standings = const [];
  List<XgStanding> xgStandings = const [];
  bool _isStandingLoading = true;
  Object? _standingLoadError;
  int _standingRequestId = 0;
  bool _isXgLoading = false;
  Object? _xgLoadError;
  int _xgRequestId = 0;

  int? currentTeamId;
  List<Season> _teamSeasons = [];

  StandingView _selectedView = StandingView.standing;

  bool get _xgAvailable => _big5LeagueIds.contains(selectedLeagueId);
  bool get _hasStandingContext => _teamSeasons.isNotEmpty;

  StandingRepository get _regularStandingRepository =>
      widget.regularStandingRepository ?? apiStandingRepository;

  StandingRepository _regularRepositoryFor(StandingTab configuration) =>
      configuration.regularStandingRepository ?? apiStandingRepository;

  XgStandingRepository get _xgStandingRepository =>
      widget.xgStandingRepository ?? apiXgStandingRepository;

  XgStandingRepository _xgRepositoryFor(StandingTab configuration) =>
      configuration.xgStandingRepository ?? apiXgStandingRepository;

  // 챔스는 과거 원정 다득점까지 검증한 2017/18 시즌부터 열어요.
  bool get _knockoutBracketAvailable =>
      TournamentBracketRepository.supportedCompetitions
          .contains(selectedLeagueId) &&
      (seasonRepository.findById(selectedSeasonId)?.name.compareTo(
                  selectedLeagueId == 2 ? '2017/2018' : '2024/2025') ??
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
    _regularStandingRepository.cachedTables.addListener(_handleStandingCache);
    _xgStandingRepository.cachedTables.addListener(_handleXgStandingCache);
    _startStandingLoad(updateState: false);

    _horizontalScrollController.addListener(_handleHorizontalScroll);
  }

  @override
  void didUpdateWidget(StandingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRegularRepository = _regularRepositoryFor(oldWidget);
    final regularRepositoryChanged =
        !identical(oldRegularRepository, _regularStandingRepository);
    if (regularRepositoryChanged) {
      oldRegularRepository.cachedTables.removeListener(_handleStandingCache);
      _regularStandingRepository.cachedTables.addListener(_handleStandingCache);
    }
    final oldXgRepository = _xgRepositoryFor(oldWidget);
    final xgRepositoryChanged =
        !identical(oldXgRepository, _xgStandingRepository);
    if (xgRepositoryChanged) {
      oldXgRepository.cachedTables.removeListener(_handleXgStandingCache);
      _xgStandingRepository.cachedTables.addListener(_handleXgStandingCache);
    }
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so redo the team-based setup
    // instead of only doing it once in initState.
    final dependenciesChanged = widget.team?.id != oldWidget.team?.id ||
        regularRepositoryChanged ||
        xgRepositoryChanged;
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

  void _handleStandingCache() {
    if (!_hasStandingContext) return;
    final cached = _regularStandingRepository.cachedForCompetition(
      selectedLeagueId,
      seasonId: selectedSeasonId,
    );
    if (cached == null || identical(standings, cached)) return;
    setState(() {
      standings = cached;
      _isStandingLoading = false;
      _standingLoadError = null;
    });
  }

  void _handleXgStandingCache() {
    if (!_hasStandingContext || !_xgAvailable) return;
    final cached = _xgStandingRepository.cachedForCompetition(
      selectedLeagueId,
      seasonId: selectedSeasonId,
    );
    if (cached == null || identical(xgStandings, cached)) return;
    setState(() {
      xgStandings = cached;
      _isXgLoading = false;
      _xgLoadError = null;
    });
  }

  void _setDefaultLeagueAndSeason() {
    currentTeamId = widget.team?.id;
    final memberships = footballCatalog.memberships
        .where((m) => m.teamId == currentTeamId)
        .map((m) => (m.seasonId, m.competitionId))
        .toSet();
    _teamSeasons = seasonRepository.allSeasons
        .where((s) => memberships.contains((s.seasonId, s.competitionId)))
        .toList()
      ..sort((a, b) {
        final bySeason =
            compactSeasonLabel(b.name).compareTo(compactSeasonLabel(a.name));
        if (bySeason != 0) return bySeason;
        return (_big5LeagueIds.contains(a.competitionId) ? 0 : 1)
            .compareTo(_big5LeagueIds.contains(b.competitionId) ? 0 : 1);
      });
    if (!_hasStandingContext) return;

    selectedLeagueId = _teamSeasons.first.competitionId;
    selectedSeasonId = _teamSeasons.first.seasonId;
    _selectedView = _defaultView;
  }

  bool _applyRequestedCompetition(int? competitionId) {
    final seasons =
        _teamSeasons.where((season) => season.competitionId == competitionId);
    if (seasons.isEmpty) return false;

    final season = seasons.where((season) => season.isCurrent).firstOrNull ??
        seasons.first;
    selectedLeagueId = season.competitionId;
    selectedSeasonId = season.seasonId;
    _selectedView = _defaultView;
    return true;
  }

  void _selectOverviewCompetition(int competitionId) {
    if (!_applyRequestedCompetition(competitionId)) return;
    _resetXgState();
    _startStandingLoad();
  }

  void _selectSeason(Season season) {
    final previousView = _selectedView;
    setState(() {
      selectedLeagueId = season.competitionId;
      selectedSeasonId = season.seasonId;
      _selectedView = _viewAfterSelectionChange(previousView);
    });
    if (_selectedView == StandingView.xgTable && _xgAvailable) {
      _startXgLoad();
    } else {
      _resetXgState();
    }
    _startStandingLoad();
  }

  Iterable<Season> get _selectedYearSeasons {
    final selected = _teamSeasons
        .firstWhere((season) => season.seasonId == selectedSeasonId);
    // 같은 연도도 대회마다 시즌 ID가 달라서 공통 시즌 표기로 묶어요.
    final label = compactSeasonLabel(selected.name);
    return _teamSeasons
        .where((season) => compactSeasonLabel(season.name) == label);
  }

  List<Season> get _seasonOptions {
    final options = <String, Season>{};
    for (final season in _teamSeasons) {
      final label = compactSeasonLabel(season.name);
      // 선택한 대회의 참가 이력이 없으면 그 시즌의 국내 리그를 먼저 열어요.
      if (!options.containsKey(label) ||
          season.competitionId == selectedLeagueId) {
        options[label] = season;
      }
    }
    return options.values.toList();
  }

  @override
  void dispose() {
    _regularStandingRepository.cachedTables
        .removeListener(_handleStandingCache);
    _xgStandingRepository.cachedTables.removeListener(_handleXgStandingCache);
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

  void _resetXgState() {
    _xgRequestId++;
    xgStandings = const [];
    _isXgLoading = false;
    _xgLoadError = null;
  }

  void _startXgLoad({
    bool updateState = true,
    bool forceRefresh = false,
  }) {
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
      xgStandings = cached ?? const [];
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
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _loadXgStandings({
    required int competitionId,
    required int seasonId,
    required int requestId,
    bool forceRefresh = false,
  }) async {
    try {
      final rows = await (forceRefresh
          ? _xgStandingRepository.refreshForCompetition(
              competitionId,
              seasonId: seasonId,
            )
          : _xgStandingRepository.loadForCompetition(
              competitionId,
              seasonId: seasonId,
            ));
      if (!mounted ||
          requestId != _xgRequestId ||
          competitionId != selectedLeagueId ||
          seasonId != selectedSeasonId) {
        return;
      }
      setState(() {
        xgStandings = rows;
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

  void _startStandingLoad({
    bool updateState = true,
    bool forceRefresh = false,
  }) {
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
      standings = cached ?? const [];
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
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _loadStandings({
    required int competitionId,
    required int seasonId,
    required int requestId,
    bool forceRefresh = false,
  }) async {
    try {
      final rows = await (forceRefresh
          ? _regularStandingRepository.refreshForCompetition(
              competitionId,
              seasonId: seasonId,
            )
          : _regularStandingRepository.loadForCompetition(
              competitionId,
              seasonId: seasonId,
            ));
      if (!mounted ||
          requestId != _standingRequestId ||
          competitionId != selectedLeagueId ||
          seasonId != selectedSeasonId) {
        return;
      }
      setState(() {
        standings = rows;
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
      return PageRefreshPlaceholder(
        child: Text(
          tr(context, 'No standings available'),
          key: ValueKey('standing-unavailable'),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  key: const ValueKey('standing-filter-row'),
                  children: [
                    Flexible(child: _buildLeagueDropdown()),
                    const SizedBox(width: 16),
                    _buildSeasonDropdown(),
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
              const SizedBox(height: 24),
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
            child: Center(child: FootballLoadingIndicator()),
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
            child: Center(child: FootballLoadingIndicator()),
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
    final leagueIds =
        _selectedYearSeasons.map((season) => season.competitionId).toSet();
    final availableLeagues = competitionRepository.allCompetitions
        .where((league) => leagueIds.contains(league.competitionId));

    return AppDropdown<int>(
      key: const ValueKey('standing-league-filter-shell'),
      triggerKey: const ValueKey('standing-league-filter'),
      value: selectedLeagueId,
      triggerHeight: 48,
      triggerPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      leading: CompetitionLogo(
        competitionId: selectedLeagueId,
        trailingGap: AppDropdownTokens.gap,
      ),
      backgroundColor: appColors.subtleBackground,
      foregroundColor: colors.onSurface,
      textStyle: Body2_b.style,
      onChanged: (val) {
        _selectSeason(_selectedYearSeasons
            .firstWhere((season) => season.competitionId == val));
      },
      options: availableLeagues
          .map(
            (league) => AppDropdownOption<int>(
              value: league.competitionId,
              leading: CompetitionLogo(
                competitionId: league.competitionId,
                trailingGap: AppDropdownTokens.gap,
              ),
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
    final seasons = _seasonOptions;

    return AppDropdown<int>(
      key: const ValueKey('standing-season-filter-shell'),
      triggerKey: const ValueKey('standing-season-filter'),
      value: selectedSeasonId,
      triggerHeight: 48,
      triggerPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      backgroundColor: appColors.subtleBackground,
      foregroundColor: colors.onSurface,
      textStyle: Body2_b.style,
      onChanged: (val) {
        _selectSeason(seasons.firstWhere((season) => season.seasonId == val));
      },
      options: seasons
          .map(
            (season) => AppDropdownOption<int>(
              value: season.seasonId,
              label: compactSeasonLabel(season.name).toUpperCase(),
            ),
          )
          .toList(),
    );
  }
}
