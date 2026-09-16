import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_repository_provider.dart'
    as community_providers;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/posts/post_repository_provider.dart'
    as post_providers;
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/models/post.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final PostRepository? postRepository;
  final CommunityRepository? communityRepository;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.postRepository,
    this.communityRepository,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // 1. Add Scroll Controller and Offset variable
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  PostRepository get _postRepository =>
      widget.postRepository ?? post_providers.postRepository;

  CommunityRepository get _communityRepository =>
      widget.communityRepository ?? community_providers.communityRepository;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Calculate opacity (0.0 at top, 1.0 when scrolled down 150px)
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final post = widget.post;

    final pageBackground = mainPageBackground(context);
    final colors = Theme.of(context).colorScheme;
    final favoriteTeamColor = Color(
      teamRepository.requireById(FavoriteTeam.id.value).primaryColor,
    );
    final gradientHeight = responsiveBrandGradientHeight(context);

    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 3. Background Gradient with AnimatedOpacity
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor), // Fades out as you scroll down
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: const ValueKey('community-detail-brand-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      favoriteTeamColor,
                      favoriteTeamColor.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController, // Bind the controller
            slivers: [
              SliverAppBar(
                // 4. Fade AppBar background to black as you scroll
                backgroundColor: Color.lerp(
                  Colors.transparent,
                  pageBackground,
                  opacityFactor,
                ),
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: colors.onSurface,
                  ),
                  onPressed: () => context.pop(),
                ),
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        favoriteTeamColor,
                        favoriteTeamColor.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.9],
                    ),
                  ),
                ),
                floating: true,
                snap: true,
              ),
              PostDetailContent(
                post: post,
                communityRepository: _communityRepository,
                onReport: (reason) => _postRepository.reportPost(
                  postId: post.postId,
                  reason: reason,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const PostDetailReplyBar(),
    );
  }
}
