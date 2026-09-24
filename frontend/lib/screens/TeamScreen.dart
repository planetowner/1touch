import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_navigation.dart';
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
  double _scrollOffset = 0.0;

  Map<String, dynamic>? team;
  bool isLoading = true;
  Object? _loadError;
  int _loadRequestId = 0;
  int? _requestedStandingCompetitionId;
  int _standingSelectionRequestId = 0;

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
    final double opacityFactor = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    final appBarForeground = colors.onSurface;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: pageBackground,
      body: Stack(
        children: [
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
                flexibleSpace: ColoredBox(color: pageBackground),
                title: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: isTeamPageSupported(displayedTeamId)
                            ? () => openTeamPage(context, displayedTeamId)
                            : null,
                        child: SizedBox.square(
                          key: const ValueKey('team-app-bar-logo'),
                          dimension: 48,
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
                              // '1. Fußballclub Heidenheim 1846 e.V',
                              teamNameLabel(context, widget.teamId,
                                  team?['name'] as String? ?? ''),
                              style: Heading4.style
                                  .copyWith(color: appBarForeground),
                              maxLines: 1, // Ensure it stays on one line
                              overflow: TextOverflow
                                  .ellipsis, // Now this will work correctly
                            ),
                            if (positionLabel.isNotEmpty)
                              Row(
                                key: const ValueKey('team-context-label'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      positionLabel,
                                      style: Body2.style
                                          .copyWith(color: appBarForeground),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (team!['rankChange'] case final int delta
                                      when delta != 0) ...[
                                    Icon(
                                      delta > 0
                                          ? Icons.arrow_drop_up
                                          : Icons.arrow_drop_down,
                                      key: const ValueKey(
                                        'team-rank-change-icon',
                                      ),
                                      size: 16,
                                      color:
                                          delta > 0 ? Colors.green : Colors.red,
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
                        ),
                      )
                    ],
                  ),
                ),
                actions: [
                  Padding(
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
                    tabs: [
                      Tab(text: tr(context, "Overview")),
                      Tab(text: tr(context, "Matches")),
                      Tab(text: tr(context, "Standing")),
                      Tab(text: tr(context, "Squad")),
                      Tab(text: tr(context, "Analysis")),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(
                  team: team,
                  onStandingCompetitionSelected: _openStandingCompetition,
                  standingRepository: widget.standingRepository,
                ),
                MatchesTab(
                    team: team, fixtureRepository: widget.fixtureRepository),
                StandingTab(
                  team: team,
                  regularStandingRepository: widget.standingRepository,
                  xgStandingRepository: widget.xgStandingRepository,
                  requestedCompetitionId: _requestedStandingCompetitionId,
                  selectionRequestId: _standingSelectionRequestId,
                ),
                SquadTab(team: team),
                AnalysisTab(
                  team: team,
                  repository: widget.teamAttributeRepository,
                  probabilityRepository: widget.teamProbabilityRepository,
                  currentFormRepository: widget.currentFormRepository,
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
