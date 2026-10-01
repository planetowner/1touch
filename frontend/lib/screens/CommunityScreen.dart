import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_repository_provider.dart'
    as community_providers;
import 'package:onetouch/data/community/community_rules_visit_repository.dart';
import 'package:onetouch/data/community/community_rules_visit_repository_provider.dart'
    as rules_visit_providers;
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_providers;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/features/community/community_header_slivers.dart';
import 'package:onetouch/features/community/community_access.dart';
import 'package:onetouch/features/community/community_post_body.dart';
import 'package:onetouch/screens/CommunityScreen_utils/AddPost.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';

class Community extends StatefulWidget {
  final int teamId;
  final PostRepository? postRepository;
  final CommunityRepository? communityRepository;
  final FixtureRepository? fixtureRepository;
  final CommunityRulesVisitRepository? rulesVisitRepository;

  const Community({
    super.key,
    required this.teamId,
    this.postRepository,
    this.communityRepository,
    this.fixtureRepository,
    this.rulesVisitRepository,
  });

  @override
  State<Community> createState() => _CommunityState();
}

class _CommunityState extends State<Community>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey();
  double _scrollOffset = 0.0;
  int _selectedTabIndex = 0;
  PostSort _selectedPostSort = PostSort.newest;

  late Team _team;
  bool _isLive = false;
  int _liveFixtureRequestId = 0;
  int? _followerCount;
  int _followerRequestId = 0;
  late final List<List<Post>> _postsByTab;
  late final List<bool> _isLoadingPostsByTab;
  late final List<Object?> _postLoadErrorsByTab;
  int _postRequestId = 0;
  int _tabViewEpoch = 0;
  bool _isActiveTab = true;
  bool _checkedRulesThisVisit = false;
  int _rulesVisitGeneration = 0;

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;

  CommunityRepository get _communityRepository =>
      widget.communityRepository ?? community_providers.communityRepository;

  CommunityRulesVisitRepository get _rulesVisitRepository =>
      widget.rulesVisitRepository ??
      rules_visit_providers.communityRulesVisitRepository;

  @override
  void initState() {
    super.initState();

    _loadTeam();
    _loadLiveStatus();
    _loadFollowerCount();

    final tabCount = CommunityPostTabHeader.categories.length;
    _postsByTab = List.generate(tabCount, (_) => const <Post>[]);
    _isLoadingPostsByTab = List<bool>.filled(tabCount, true);
    _postLoadErrorsByTab = List<Object?>.filled(tabCount, null);

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _tabController = TabController(length: tabCount, vsync: this)
      ..addListener(_handlePostTabChange);
    mainTabActions.addListener(_handleMainTabAction);
    _loadPosts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showFirstVisitRules();
    });
  }

  Future<void> _showFirstVisitRules() async {
    if (!_isActiveTab || _checkedRulesThisVisit) return;
    _checkedRulesThisVisit = true;
    final generation = _rulesVisitGeneration;
    try {
      if (!await _rulesVisitRepository.shouldShow() ||
          !mounted ||
          !_isActiveTab ||
          generation != _rulesVisitGeneration) {
        return;
      }
      final acknowledged = await showGroundRulesModal(
        context,
        teamId: widget.teamId,
        repository: _communityRepository,
      );
      if (acknowledged == true) await _rulesVisitRepository.acknowledge();
    } on Object {
      // Local storage errors must not prevent the community from opening.
    }
  }

  void _handlePostTabChange() {
    final index = _tabController.index;
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    _loadPosts();
  }

  void _handleMainTabAction() {
    final active = mainTabActions.tabIndex == 3;
    if (active != _isActiveTab) {
      _isActiveTab = active;
      _rulesVisitGeneration++;
      _checkedRulesThisVisit = false;
      if (active) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showFirstVisitRules();
        });
      }
    }
    if (_selectedTabIndex != 0) {
      _selectedTabIndex = 0;
      _tabController.index = 0;
      setState(() => _tabViewEpoch++);
      _loadPosts();
    }
    if (mainTabActions.tabIndex != 3) return;
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

  Future<void> _refreshCommunity() => Future.wait<void>([
        _loadLiveStatus(),
        _loadFollowerCount(),
        _loadPosts(preserveCurrentPosts: true),
      ]);

  @override
  void didUpdateWidget(Community oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 탭 상태가 유지되므로 홈에서 조회 팀이 바뀌면 헤더와 콘텐츠를 함께 다시 불러와요.
    if (widget.teamId != oldWidget.teamId) {
      setState(() {
        _loadTeam();
        _isLive = false;
        _resetPostFeeds();
      });
      _loadLiveStatus();
      _loadFollowerCount();
      _loadPosts();
    }
    if (widget.teamId == oldWidget.teamId &&
        widget.fixtureRepository != oldWidget.fixtureRepository) {
      setState(() => _isLive = false);
      _loadLiveStatus();
    }
    if (widget.teamId == oldWidget.teamId &&
        widget.communityRepository != oldWidget.communityRepository) {
      _loadFollowerCount();
    }
    if (widget.teamId == oldWidget.teamId &&
        widget.postRepository != oldWidget.postRepository) {
      _resetPostFeeds();
      _loadPosts();
    }
  }

  void _resetPostFeeds() {
    _postRequestId++;
    for (var index = 0; index < _postsByTab.length; index++) {
      _postsByTab[index] = const <Post>[];
      _isLoadingPostsByTab[index] = true;
      _postLoadErrorsByTab[index] = null;
    }
  }

  void _loadTeam() {
    _team = teamRepository.requireById(widget.teamId);
  }

  Future<void> _loadLiveStatus() async {
    final requestId = ++_liveFixtureRequestId;
    final teamId = widget.teamId;

    try {
      final repository =
          widget.fixtureRepository ?? fixture_providers.fixtureDetailRepository;
      final fixtures = await repository.loadForTeam(
        teamId,
        status: FixtureStatus.live,
        limit: 1,
      );
      if (!mounted ||
          requestId != _liveFixtureRequestId ||
          teamId != widget.teamId) {
        return;
      }

      final hasLiveMatch = fixtures.any(
        (fixture) =>
            fixture.status == FixtureStatus.live &&
            (fixture.homeTeamId == teamId || fixture.awayTeamId == teamId),
      );
      if (_isLive != hasLiveMatch) {
        setState(() => _isLive = hasLiveMatch);
      }
    } catch (_) {
      // A failed or unavailable fixture request must never create a live badge.
      if (!mounted ||
          requestId != _liveFixtureRequestId ||
          teamId != widget.teamId) {
        return;
      }
      if (_isLive) {
        setState(() => _isLive = false);
      }
    }
  }

  Future<void> _loadFollowerCount() async {
    final requestId = ++_followerRequestId;
    setState(() => _followerCount = null);
    try {
      final count = await _communityRepository.loadFollowerCount(
        teamId: widget.teamId,
      );
      if (!mounted || requestId != _followerRequestId) return;
      setState(() => _followerCount = count);
    } catch (_) {
      // Follower totals are supplementary. Keep the label available without
      // inventing a count when this independent request is unavailable.
      if (!mounted || requestId != _followerRequestId) return;
      setState(() => _followerCount = null);
    }
  }

  Future<void> _loadPosts({bool preserveCurrentPosts = false}) async {
    final requestId = ++_postRequestId;
    final tabIndex = _selectedTabIndex;
    final preserveCurrent =
        preserveCurrentPosts && _postsByTab[tabIndex].isNotEmpty;
    final category = CommunityPostTabHeader.categories[tabIndex];
    setState(() {
      _isLoadingPostsByTab[tabIndex] = !preserveCurrent;
      _postLoadErrorsByTab[tabIndex] = null;
    });

    try {
      final posts = await _postRepository.loadPosts(
        teamId: widget.teamId,
        category: category,
        sort: _selectedPostSort,
      );
      if (!mounted || requestId != _postRequestId) return;
      setState(() {
        _postsByTab[tabIndex] = posts;
        _isLoadingPostsByTab[tabIndex] = false;
      });
    } catch (error) {
      if (!mounted || requestId != _postRequestId) return;
      setState(() {
        _postLoadErrorsByTab[tabIndex] = preserveCurrent ? null : error;
        _isLoadingPostsByTab[tabIndex] = false;
      });
    }
  }

  void _selectPostSort(PostSort sort) {
    if (_selectedPostSort == sort) return;
    _selectedPostSort = sort;
    for (var index = 0; index < _postsByTab.length; index++) {
      if (index == _selectedTabIndex) continue;
      _postsByTab[index] = const <Post>[];
      _isLoadingPostsByTab[index] = true;
      _postLoadErrorsByTab[index] = null;
    }
    _loadPosts(preserveCurrentPosts: true);
  }

  void _selectPostTab(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    _loadPosts();
  }

  Future<void> _openPostComposer() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPost(
          teamId: widget.teamId,
          postRepository: _postRepository,
        ),
      ),
    );
    if (!mounted || created != true) return;

    await _loadPosts();
  }

  @override
  void dispose() {
    mainTabActions.removeListener(_handleMainTabAction);
    _scrollController.dispose();
    _tabController.removeListener(_handlePostTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final team = _team;

    return CommunityAccessBuilder(
      teamId: widget.teamId,
      builder: (context, canParticipate) => Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: pageBackground,
        bottomNavigationBar:
            canParticipate ? null : const CommunityReadOnlyNotice(),
        floatingActionButton: canParticipate
            ? FloatingActionButton(
                backgroundColor: Colors.white,
                elevation: 0,
                shape: const CircleBorder(),
                onPressed: _openPostComposer,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -2.5),
                    child: SvgPicture.asset(
                      'assets/addpost_icon.svg',
                      height: 40,
                      width: 40,
                    ),
                  ),
                ),
              )
            : null,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshCommunity,
              notificationPredicate: (notification) => notification.depth <= 1,
              child: NestedScrollView(
                key: _nestedScrollKey,
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  CommunitySliverAppBar(
                    pageBackground: pageBackground,
                    opacityFactor: opacityFactor,
                    onSearch: () => context.push('/search'),
                    onNotifications: () => context.push('/notifications'),
                    onActivity: () =>
                        context.push('/profile/activity?tab=posts'),
                  ),
                  CommunityTeamHeader(
                    team: team,
                    isLive: _isLive,
                    followerCount: _followerCount,
                    onTeamTap: isTeamPageSupported(team.teamId)
                        ? () => openTeamPage(context, team.teamId)
                        : null,
                  ),
                  CommunityPostTabHeader(
                    controller: _tabController,
                    onTap: _selectPostTab,
                  ),
                ],
                body: TabBarView(
                  key: ValueKey('community-tab-view-$_tabViewEpoch'),
                  controller: _tabController,
                  children: [
                    for (var index = 0;
                        index < CommunityPostTabHeader.categories.length;
                        index++)
                      CommunityPostBody(
                        teamId: widget.teamId,
                        posts: _postsByTab[index],
                        postRepository: _postRepository,
                        communityRepository: _communityRepository,
                        selectedSort: _selectedPostSort,
                        isLoading: _isLoadingPostsByTab[index],
                        loadError: _postLoadErrorsByTab[index],
                        onRetry: _loadPosts,
                        onPostDetailClosed: () => _loadPosts(
                          preserveCurrentPosts: true,
                        ),
                        onPostUpdated: _loadPosts,
                        onSortChanged: _selectPostSort,
                      ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
