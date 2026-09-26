import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository_provider.dart'
    as team_overview_providers;
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart'
    as team_providers;
import 'package:onetouch/features/helper.dart';
import 'TeamScreen_tabs/index.dart';
import '../models/team_overview.dart';
import 'package:onetouch/l10n/app_localizations.dart';

const double _teamAppBarBaseToolbarHeight = 80;
const double _teamAppBarLogoSize = 48;
const double _teamAppBarMinimumContentTop = 47;

class TeamScreen extends StatefulWidget {
  final int teamId;
  final TeamAttributeRepository? teamAttributeRepository;
  final TeamOverviewRepository? teamOverviewRepository;
  final TeamProbabilityRepository? teamProbabilityRepository;
  final StandingRepository? standingRepository;
  final XgStandingRepository? xgStandingRepository;
  final FixtureRepository? fixtureRepository;
  final CurrentFormRepository? currentFormRepository;

  TeamScreen({
    super.key,
    required this.teamId,
    this.teamAttributeRepository,
    this.teamOverviewRepository,
    this.teamProbabilityRepository,
    this.standingRepository,
    this.xgStandingRepository,
    this.fixtureRepository,
    this.currentFormRepository,
  });

  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TabController _tabController;
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey();

  Map<String, dynamic>? team;
  bool isLoading = true;
  Object? _loadError;
  int _loadRequestId = 0;
  int? _requestedStandingCompetitionId;
  int _standingSelectionRequestId = 0;
  bool _isBracketInteracting = false;
  bool _isRevealingTeamAppBar = false;
  int _selectedTabIndex = 0;
  final List<int> _tabRefreshEpochs = List<int>.filled(5, 0);

  TeamOverviewRepository get _teamOverviewRepository =>
      widget.teamOverviewRepository ??
      team_overview_providers.teamOverviewRepository;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _tabController = TabController(length: 5, vsync: this)
      ..addListener(_handleTabChange);
    mainTabActions.addListener(_handleMainTabAction);

    _startOverviewLoad(updateState: false);
  }

  void _handleTabChange() {
    if (_selectedTabIndex == _tabController.index) return;
    setState(() => _selectedTabIndex = _tabController.index);
  }

  void _handleMainTabAction() {
    if (mainTabActions.tabIndex != 1) return;
    if (_tabController.index != 0) {
      _tabController.animateTo(0, duration: Duration.zero);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRootAppBar();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _showRootAppBar() {
    final innerController = _nestedScrollKey.currentState?.innerController;
    if (innerController?.hasClients ?? false) {
      innerController!.jumpTo(innerController.position.minScrollExtent);
    }
    if (!mounted || !_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
  }

  Future<void> _refreshTeam() async {
    final requestId = ++_loadRequestId;
    final selectedTab = _selectedTabIndex;
    setState(() => _tabRefreshEpochs[selectedTab] += 1);
    await _loadOverview(widget.teamId, requestId);
  }

  @override
  void didUpdateWidget(TeamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This screen's State is reused across team switches (the Team-tab
    // branch stays alive in the bottom-nav shell), so reload instead of
    // only loading once in initState — otherwise it keeps showing whichever
    // team was loaded first, forever.
    if (widget.teamId != oldWidget.teamId ||
        widget.teamOverviewRepository != oldWidget.teamOverviewRepository) {
      _startOverviewLoad();
    }
  }

  void _startOverviewLoad({bool updateState = true}) {
    final requestId = ++_loadRequestId;
    final cached = _teamOverviewRepository.cachedForTeam(widget.teamId);

    void prepare() {
      team = cached == null ? null : _teamMap(cached);
      isLoading = cached == null;
      _loadError = null;
    }

    if (updateState) {
      setState(prepare);
    } else {
      prepare();
    }
    unawaited(_loadOverview(widget.teamId, requestId));
  }

  Future<void> _loadOverview(int teamId, int requestId) async {
    try {
      final overview = await _teamOverviewRepository.loadForTeam(teamId);
      if (!mounted || requestId != _loadRequestId || teamId != widget.teamId) {
        return;
      }
      setState(() {
        team = _teamMap(overview);
        isLoading = false;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted || requestId != _loadRequestId || teamId != widget.teamId) {
        return;
      }
      setState(() {
        isLoading = false;
        if (team == null) _loadError = error;
      });
    }
  }

  Map<String, dynamic> _teamMap(TeamOverview overview) {
    final leagueName = team_providers.teamCompetitionContextResolver
        .resolve(overview.id)
        ?.competitionName;
    final positionValue = overview.standing?['position'];
    final rankDeltaValue = overview.standing?['rank_delta'];

    return {
      'id': overview.id,
      'name': overview.name,
      'short_code': overview.shortName,
      'image_path': overview.imagePath,
      'position': positionValue,
      'leagueName': leagueName,
      'logo': overview.imagePath,
      'rankChange': rankDeltaValue is int ? rankDeltaValue : null,
      'standing': overview.standing,
      'next_match': overview.nextMatch,
      'last_match': overview.lastMatch,
      'teamObj': overview,
    };
  }

  void _retryOverviewLoad() {
    _startOverviewLoad();
  }

  void _openStandingCompetition(int competitionId) {
    setState(() {
      _requestedStandingCompetitionId = competitionId;
      _standingSelectionRequestId++;
    });
    _tabController.animateTo(2);
  }

  void _revealTeamAppBar() {
    if (_isRevealingTeamAppBar ||
        !_scrollController.hasClients ||
        _scrollController.offset <= 0) {
      return;
    }
    _isRevealingTeamAppBar = true;
    _scrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _isRevealingTeamAppBar = false);
  }

  @override
  void dispose() {
    mainTabActions.removeListener(_handleMainTabAction);
    _scrollController.dispose();
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final pageBackground = mainPageBackground(context);

    if (isLoading) {
      return Scaffold(
        backgroundColor: pageBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (team == null) {
      return Scaffold(
        key: const ValueKey('team-load-error'),
        backgroundColor: pageBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(context, 'Unable to load team'), style: Body1.style),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey('team-retry'),
                onPressed: _loadError == null ? null : _retryOverviewLoad,
                child: Text(tr(context, 'RETRY')),
              ),
            ],
          ),
        ),
      );
    }

    // 지역화한 문구는 화면을 그릴 때 만들어 언어 변경도 바로 반영해요.
    final originalLeagueName = team!['leagueName'] as String?;
    final leagueName = originalLeagueName == null
        ? null
        : competitionNameLabel(
            context,
            team_providers.teamCompetitionContextResolver
                .resolve(widget.teamId)
                ?.competitionId,
            originalLeagueName);
    final rank = team!['position'];
    final positionLabel = leagueName == null
        ? ''
        : rank is int
            ? '$leagueName ${ordinal(rank, locale: Localizations.localeOf(context))}'
            : leagueName;
    final displayedTeamId = team!['id'] as int;
    final appBarForeground = colors.onSurface;
    final topInset = MediaQuery.paddingOf(context).top;
    const baseToolbarVerticalPadding =
        (_teamAppBarBaseToolbarHeight - _teamAppBarLogoSize) / 2;
    final currentContentTop = topInset + baseToolbarVerticalPadding;
    final additionalTopSpace = currentContentTop < _teamAppBarMinimumContentTop
        ? _teamAppBarMinimumContentTop - currentContentTop
        : 0.0;
    final toolbarHeight = _teamAppBarBaseToolbarHeight + additionalTopSpace;
    final toolbarContentOffset = additionalTopSpace / 2;

    return Scaffold(
      backgroundColor: pageBackground,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshTeam,
            notificationPredicate: (notification) => notification.depth <= 1,
            child: NestedScrollView(
              key: _nestedScrollKey,
              controller: _scrollController,
              floatHeaderSlivers: false,
              physics: _isBracketInteracting
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: pageBackground,
                  foregroundColor: appBarForeground,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  forceMaterialTransparency: false,
                  floating: false,
                  snap: false,
                  pinned: false,
                  toolbarHeight: toolbarHeight,
                  flexibleSpace: ColoredBox(color: pageBackground),
                  bottom: PreferredSize(
                    key: const ValueKey('team-tab-header'),
                    preferredSize: const Size.fromHeight(kTextTabBarHeight + 8),
                    child: ColoredBox(
                      color: pageBackground,
                      child: SizedBox(
                        height: kTextTabBarHeight + 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            labelColor: colors.onSurface,
                            unselectedLabelColor: appColors.mutedForeground,
                            indicatorColor: colors.onSurface,
                            labelStyle: Heading5.style,
                            unselectedLabelStyle: Heading5.style,
                            indicatorSize: TabBarIndicatorSize.label,
                            dividerColor: Colors.transparent,
                            padding: const EdgeInsets.only(left: 8),
                            indicator: UnderlineTabIndicator(
                              borderSide: BorderSide(
                                color: colors.onSurface,
                                width: 2,
                              ),
                            ),
                            tabs: [
                              Tab(text: teamScreenLabel(context, "Overview")),
                              Tab(text: teamScreenLabel(context, "Matches")),
                              Tab(text: tr(context, "Standing")),
                              Tab(text: tr(context, "Squad")),
                              Tab(text: tr(context, "Analysis")),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Transform.translate(
                    offset: Offset(0, toolbarContentOffset),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: isTeamPageSupported(displayedTeamId)
                                ? () => openTeamPage(context, displayedTeamId)
                                : null,
                            child: SizedBox.square(
                              key: const ValueKey('team-app-bar-logo'),
                              dimension: _teamAppBarLogoSize,
                              child: Image.network(
                                team?['logo'],
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => teamLogoFallback(
                                  team!['id'] as int,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  key: const ValueKey('team-app-bar-name'),
                                  // '1. Fußballclub Heidenheim 1846 e.V',
                                  teamNameLabel(context, widget.teamId,
                                      team?['name'] as String? ?? ''),
                                  style: Heading4.style
                                      .copyWith(color: appBarForeground),
                                  maxLines: 1, // Ensure it stays on one line
                                  overflow: TextOverflow
                                      .ellipsis, // Now this will work correctly
                                ),
                                if (positionLabel.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    key: const ValueKey('team-context-label'),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          positionLabel,
                                          style: Body2.style.copyWith(
                                              color: appBarForeground),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (team!['rankChange']
                                          case final int delta
                                          when delta != 0) ...[
                                        Icon(
                                          delta > 0
                                              ? Icons.arrow_drop_up
                                              : Icons.arrow_drop_down,
                                          key: const ValueKey(
                                            'team-rank-change-icon',
                                          ),
                                          size: 16,
                                          color: delta > 0
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        Text(
                                          '${delta.abs()}',
                                          key: const ValueKey(
                                            'team-rank-change-value',
                                          ),
                                          style: Eyebrow.style.copyWith(
                                            color: delta > 0
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    Transform.translate(
                      offset: Offset(0, toolbarContentOffset),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          key: const Key('team-search-button'),
                          onPressed: () => context.push('/search'),
                          icon: Icon(
                            Icons.search,
                            size: 32,
                            color: appBarForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                physics: _isBracketInteracting
                    ? const NeverScrollableScrollPhysics()
                    : null,
                children: [
                  OverviewTab(
                    key: ValueKey(
                      'team-overview-refresh-${_tabRefreshEpochs[0]}',
                    ),
                    team: team,
                    onStandingCompetitionSelected: _openStandingCompetition,
                    standingRepository: widget.standingRepository,
                  ),
                  MatchesTab(
                    key: ValueKey(
                      'team-matches-refresh-${_tabRefreshEpochs[1]}',
                    ),
                    team: team,
                    fixtureRepository: widget.fixtureRepository,
                    onTopOverscroll: _revealTeamAppBar,
                  ),
                  StandingTab(
                    key: ValueKey(
                      'team-standing-refresh-${_tabRefreshEpochs[2]}',
                    ),
                    team: team,
                    regularStandingRepository: widget.standingRepository,
                    xgStandingRepository: widget.xgStandingRepository,
                    requestedCompetitionId: _requestedStandingCompetitionId,
                    selectionRequestId: _standingSelectionRequestId,
                    onBracketInteractionChanged: (isInteracting) {
                      if (_isBracketInteracting == isInteracting) return;
                      setState(() => _isBracketInteracting = isInteracting);
                    },
                  ),
                  SquadTab(
                    key: ValueKey(
                      'team-squad-refresh-${_tabRefreshEpochs[3]}',
                    ),
                    team: team,
                  ),
                  AnalysisTab(
                    key: ValueKey(
                      'team-analysis-refresh-${_tabRefreshEpochs[4]}',
                    ),
                    team: team,
                    repository: widget.teamAttributeRepository,
                    probabilityRepository: widget.teamProbabilityRepository,
                    currentFormRepository: widget.currentFormRepository,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
