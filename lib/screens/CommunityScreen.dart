import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/community/mock/community_catalog.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/screens/CommunityScreen_utils/AddPost.dart';
import 'package:onetouch/screens/CommunityScreen_utils/All.dart';

String _formatFollowers(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M Followers';
  }
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K Followers';
  return '$count Followers';
}

class Community extends StatefulWidget {
  final int teamId;
  final PostRepository? postRepository;

  const Community({
    super.key,
    required this.teamId,
    this.postRepository,
  });

  @override
  State<Community> createState() => _CommunityState();
}

class _CommunityState extends State<Community>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  double _scrollOffset = 0.0;
  int _selectedTabIndex = 0;
  PostSort _selectedPostSort = PostSort.newest;

  late Team _team;
  late bool _isLive;
  late int _followerCount;
  List<Post> _posts = const [];
  bool _isLoadingPosts = true;
  Object? _postLoadError;
  int _postRequestId = 0;

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;

  @override
  void initState() {
    super.initState();

    _loadTeam();
    _loadPosts();

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didUpdateWidget(Community oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The favorite team can change while this screen stays alive (its branch
    // in the bottom-nav shell is kept in memory), so re-resolve when the
    // parent route hands us a different teamId instead of only on first load.
    if (widget.teamId != oldWidget.teamId) {
      setState(_loadTeam);
    }
    if (widget.postRepository != oldWidget.postRepository) {
      _loadPosts();
    }
  }

  void _loadTeam() {
    _team = teamRepository.requireById(widget.teamId);
    _isLive = fixtureRepository
        .forTeam(widget.teamId, status: FixtureStatus.live)
        .isNotEmpty;
    _followerCount =
        mockUserFollowingTeams.where((f) => f.teamId == widget.teamId).length;
  }

  Future<void> _loadPosts() async {
    final requestId = ++_postRequestId;
    final category = switch (_selectedTabIndex) {
      1 => PostCategory.general,
      2 => PostCategory.analysis,
      3 => PostCategory.news,
      _ => null,
    };
    setState(() {
      _isLoadingPosts = true;
      _postLoadError = null;
    });

    try {
      final posts = await _postRepository.loadPosts(
        category: category,
        sort: _selectedPostSort,
      );
      if (!mounted || requestId != _postRequestId) return;
      setState(() {
        _posts = posts;
        _isLoadingPosts = false;
      });
    } catch (error) {
      if (!mounted || requestId != _postRequestId) return;
      setState(() {
        _postLoadError = error;
        _isLoadingPosts = false;
      });
    }
  }

  void _selectPostSort(PostSort sort) {
    if (_selectedPostSort == sort) return;
    _selectedPostSort = sort;
    _loadPosts();
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
        builder: (context) => AddPost(postRepository: _postRepository),
      ),
    );
    if (!mounted || created != true) return;

    await _loadPosts();
  }

  Widget _buildPostBody() {
    if (_isLoadingPosts) {
      return const Center(
        child: CircularProgressIndicator(
          key: ValueKey('community-posts-loading'),
        ),
      );
    }
    if (_postLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load community posts.',
                style: Body1.style,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('community-posts-retry'),
                onPressed: _loadPosts,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }
    return All(
      posts: _posts,
      selectedSort: _selectedPostSort,
      onSortChanged: _selectPostSort,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    const headerForeground = AppPalette.white;
    final team = _team;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: pageBackground,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        elevation: 0,
        onPressed: _openPostComposer,
        child: SvgPicture.asset(
          'assets/addpost_icon.svg',
          height: 40,
          width: 40,
        ),
      ),
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
                key: const ValueKey('community-brand-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(team.primaryColor),
                      Color(team.primaryColor).withAlpha(0)
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // AppBar: same as your current
              SliverAppBar(
                backgroundColor: Color.lerp(
                    Colors.transparent, pageBackground, opacityFactor),
                foregroundColor: AppPalette.white,
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                centerTitle: false,
                titleSpacing: 0,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(team.primaryColor),
                        Color(team.primaryColor).withAlpha(0)
                      ],
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(left: 24, top: 30),
                  child: SvgPicture.asset(
                    'assets/app_logo.svg',
                    height: 23,
                    width: 120,
                    colorFilter: const ColorFilter.mode(
                      AppPalette.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('community-search-button'),
                          onPressed: () => context.push('/search'),
                          icon: const Icon(
                            Icons.search,
                            size: 32,
                            color: AppPalette.white,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('community-profile-button'),
                          onPressed: () => context.push('/profile'),
                          icon: const Icon(Icons.account_circle_outlined,
                              size: 32, color: AppPalette.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ), // your existing AppBar

              // "Team Info"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/team/${team.teamId}'),
                        child: team.imagePath != null
                            ? Image.network(
                                team.imagePath!,
                                height: 52,
                                width: 52,
                                errorBuilder: (_, __, ___) =>
                                    teamLogoFallback(team.teamId, size: 52),
                              )
                            : const Icon(Icons.shield,
                                color: Colors.white54, size: 52),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    team.name,
                                    key: const ValueKey('community-team-name'),
                                    style: Heading4.style
                                        .copyWith(color: headerForeground),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isLive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    key: const ValueKey(
                                      'community-live-badge',
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text("LIVE",
                                        style: Body2_b.style.copyWith(
                                          color: isLight
                                              ? AppPalette.black
                                              : AppPalette.white,
                                        )),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(_formatFollowers(_followerCount),
                                style: Body2.style
                                    .copyWith(color: headerForeground)),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.star_border,
                        key: const ValueKey('community-favorite-icon'),
                        color: headerForeground,
                      ),
                    ],
                  ),
                ),
              ),

              // Tab bar (sticky)
              SliverPersistentHeader(
                floating: true,
                pinned: false,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    onTap: _selectPostTab,
                    isScrollable: true,
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
                      Tab(text: "All"),
                      Tab(text: "General"),
                      Tab(text: "Analysis"),
                      Tab(text: "News & Insights"),
                    ],
                    tabAlignment: TabAlignment.start,
                  ),
                ),
              ),
            ],
            body: _buildPostBody(),
          )
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
