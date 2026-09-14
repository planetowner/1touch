import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';
import 'package:onetouch/data/team_overview/team_overview_repository_provider.dart'
    as team_overview_providers;
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart'
    as team_providers;
import 'package:onetouch/features/helper.dart';
import 'TeamScreen_tabs/index.dart';
import '../models/team_overview.dart';

class TeamScreen extends StatefulWidget {
  final int teamId;
  final TeamRepository? teamRepository;
  final TeamAttributeRepository? teamAttributeRepository;
  final TeamOverviewRepository? teamOverviewRepository;

  TeamScreen({
    super.key,
    required this.teamId,
    this.teamRepository,
    this.teamAttributeRepository,
    this.teamOverviewRepository,
  });

  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TabController _tabController;
  double _scrollOffset = 0.0;

  Map<String, dynamic>? team;
  bool isLoading = true;
  Object? _loadError;
  int _loadRequestId = 0;
  Color _teamColor = const Color(0xFFD82457);

  TeamRepository get _teamRepository =>
      widget.teamRepository ?? team_providers.teamRepository;

  TeamOverviewRepository get _teamOverviewRepository =>
      widget.teamOverviewRepository ??
      team_overview_providers.teamOverviewRepository;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _tabController = TabController(length: 5, vsync: this); // ✅ add init

    _startOverviewLoad(updateState: false);
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
      final localTeam = _teamRepository.findById(widget.teamId);
      _teamColor = Color(localTeam?.primaryColor ?? 0xFFD82457);
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
    final leagueId =
        overview.nextMatch?.competitionId ?? overview.lastMatch?.competitionId;
    final leagueName = leagueId == null
        ? 'League'
        : competitionRepository.findById(leagueId)?.name ?? 'League';
    final positionValue = overview.standing?['position'];
    final position = positionValue is int
        ? '$leagueName ${ordinal(positionValue)}'
        : leagueName;

    return {
      'id': overview.id,
      'name': overview.name,
      'short_code': overview.shortName,
      'image_path': overview.imagePath,
      'position': position,
      'logo': overview.imagePath,
      // TODO(team-overview): The current design always renders an upward green
      // arrow. Connect the signed API rank_delta when that indicator supports
      // upward, downward, and unchanged states.
      'rankChange': 0,
      'standing': overview.standing,
      'next_match': overview.nextMatch,
      'last_match': overview.lastMatch,
      'teamObj': overview,
    };
  }

  void _retryOverviewLoad() {
    _startOverviewLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);

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
              Text('Unable to load team', style: Body1.style),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey('team-retry'),
                onPressed: _loadError == null ? null : _retryOverviewLoad,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    final double opacityFactor = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    const appBarForeground = AppPalette.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: pageBackground,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor),
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: const ValueKey('team-brand-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_teamColor, pageBackground],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Color.lerp(
                  Colors.transparent,
                  pageBackground,
                  opacityFactor,
                ),
                foregroundColor: appBarForeground,
                elevation: 0,
                floating: true,
                snap: true,
                pinned: false,
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _teamColor,
                        _teamColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/team/${team!['id']}'),
                        child: Image.network(
                          team?['logo'],
                          height: 52,
                          width: 53,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              teamLogoFallback(team!['id'] as int, size: 52),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // '1. Fußballclub Heidenheim 1846 e.V',
                              team?['name'],
                              style: Heading4.style
                                  .copyWith(color: appBarForeground),
                              maxLines: 1, // Ensure it stays on one line
                              overflow: TextOverflow
                                  .ellipsis, // Now this will work correctly
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    team!['position'] as String,
                                    style: Body2.style
                                        .copyWith(color: appBarForeground),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_up,
                                    size: 16, color: Colors.green),
                                Text(
                                  team!['rankChange'] != 0
                                      ? ' ${team!['rankChange']}'
                                      : '',
                                  style: Eyebrow.style
                                      .copyWith(color: appBarForeground),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: IconButton(
                      key: const Key('team-search-button'),
                      onPressed: () => context.push('/search'),
                      icon: const Icon(
                        Icons.search,
                        size: 32,
                        color: AppPalette.white,
                      ),
                    ),
                  ),
                ],
              ),
              SliverPersistentHeader(
                pinned: false,
                delegate: _TabBarDelegate(
                  TabBar(
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
                      borderSide: BorderSide(color: colors.onSurface, width: 2),
                    ),
                    tabs: const [
                      Tab(text: "Overview"),
                      Tab(text: "Matches"),
                      Tab(text: "Standing"),
                      Tab(text: "Squad"),
                      Tab(text: "Analysis"),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(team: team),
                MatchesTab(team: team),
                StandingTab(team: team),
                SquadTab(team: team),
                AnalysisTab(
                  team: team,
                  repository: widget.teamAttributeRepository,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent =>
      _tabBar.preferredSize.height + 8; // a bit of top padding

  @override
  double get maxExtent => _tabBar.preferredSize.height + 8;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      // color: Colors.black, // solid bg so it looks clean when pinned
      alignment: Alignment.centerLeft,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
