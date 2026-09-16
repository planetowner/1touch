import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_repository_provider.dart'
    as community_providers;
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/features/community/community_header_slivers.dart';
import 'package:onetouch/features/community/community_post_body.dart';
import 'package:onetouch/screens/CommunityScreen_utils/AddPost.dart';

class Community extends StatefulWidget {
  final int teamId;
  final PostRepository? postRepository;
  final CommunityRepository? communityRepository;

  const Community({
    super.key,
    required this.teamId,
    this.postRepository,
    this.communityRepository,
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
  int? _followerCount;
  int _followerRequestId = 0;
  List<Post> _posts = const [];
  bool _isLoadingPosts = true;
  Object? _postLoadError;
  int _postRequestId = 0;

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;

  CommunityRepository get _communityRepository =>
      widget.communityRepository ?? community_providers.communityRepository;

  @override
  void initState() {
    super.initState();

    _loadTeam();
    _loadFollowerCount();
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
      _loadFollowerCount();
      _loadPosts();
    }
    if (widget.teamId == oldWidget.teamId &&
        widget.communityRepository != oldWidget.communityRepository) {
      _loadFollowerCount();
    }
    if (widget.teamId == oldWidget.teamId &&
        widget.postRepository != oldWidget.postRepository) {
      _loadPosts();
    }
  }

  void _loadTeam() {
    _team = teamRepository.requireById(widget.teamId);
    _isLive = fixtureRepository
        .forTeam(widget.teamId, status: FixtureStatus.live)
        .isNotEmpty;
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
        teamId: widget.teamId,
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
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);
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
              CommunitySliverAppBar(
                brandColor: Color(team.primaryColor),
                pageBackground: pageBackground,
                opacityFactor: opacityFactor,
                onSearch: () => context.push('/search'),
                onProfile: () => context.push('/profile'),
              ),
              CommunityTeamHeader(
                team: team,
                isLive: _isLive,
                followerCount: _followerCount,
                onTeamTap: () => openTeamPage(context, team.teamId),
              ),
              CommunityPostTabHeader(
                controller: _tabController,
                onTap: _selectPostTab,
              ),
            ],
            body: CommunityPostBody(
              posts: _posts,
              postRepository: _postRepository,
              selectedSort: _selectedPostSort,
              isLoading: _isLoadingPosts,
              loadError: _postLoadError,
              onRetry: _loadPosts,
              onSortChanged: _selectPostSort,
            ),
          )
        ],
      ),
    );
  }
}
