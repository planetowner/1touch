import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ReportDialog.dart';

String _timeAgo(String createdAt) {
  final created = DateTime.tryParse(createdAt) ?? DateTime.now();
  final diff = DateTime.now().difference(created);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // 1. Add Scroll Controller and Offset variable
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

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

  Widget _buildPostAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 4),
                Text(label, style: Body2.style),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 2. Calculate opacity (0.0 at top, 1.0 when scrolled down 150px)
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final post = widget.post;
    final hasMedia = post.mediaUrl != null;

    final pageBackground = mainPageBackground(context);
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: () {
                          showGroundRulesModal(context);
                        },
                        child: Container(
                          key: const ValueKey(
                              'community-detail-ground-rules-card'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppPalette.lightGrey
                                : AppPalette.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.push_pin_outlined,
                                color: colors.onSurface,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "Community Ground Rules",
                                  style: Heading5.style
                                      .copyWith(color: colors.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Post content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: isDark
                                    ? Colors.white24
                                    : AppPalette.lightGrey,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("User ${post.userId}",
                                      style: Body1.style),
                                  Text(
                                    _timeAgo(post.createdAt),
                                    style: Body2.style.copyWith(
                                      color: appColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(post.title, style: Body1_b.style),
                          const SizedBox(height: 12),
                          Text(post.body, style: Body2.style),
                          const SizedBox(height: 16),

                          // Media section
                          if (hasMedia) _buildMediaPreview(post.mediaUrl!),
                          if (hasMedia) const SizedBox(height: 16),

                          const SizedBox(height: 16),

                          // Actions row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPostAction(
                                icon: Icons.thumb_up_alt_outlined,
                                label: "1,290",
                                color: colors.onSurface,
                              ),
                              _buildPostAction(
                                icon: Icons.mode_comment_outlined,
                                label: "12",
                                color: colors.onSurface,
                              ),
                              _buildPostAction(
                                icon: Icons.share,
                                label: "share",
                                color: colors.onSurface,
                              ),
                              _buildPostAction(
                                icon: Icons.report_gmailerrorred_outlined,
                                label: "report",
                                color: colors.onSurface,
                                onTap: () => showReportDialog(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Comment section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          3,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isDark
                                      ? Colors.white24
                                      : AppPalette.lightGrey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Username", style: Body2_b.style),
                                      Text(
                                        "First sentence goes here. Second sentence goes here. Third sentence goes here.",
                                        style: Body2.style,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.reply,
                                  size: 18,
                                  color: colors.onSurface,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // 📝 Reply bar
      bottomNavigationBar: Container(
        color: isDark ? AppPalette.darkGrey : AppPalette.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppPalette.lightGrey
                      : appColors.subtleBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Write a reply...",
                    hintStyle: TextStyle(color: appColors.mutedForeground),
                    border: InputBorder.none,
                    filled: false,
                  ),
                  style: TextStyle(color: colors.onSurface),
                  cursorColor: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.send, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(String mediaUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppPalette.lightGrey,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.of(context).mutedForeground,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
