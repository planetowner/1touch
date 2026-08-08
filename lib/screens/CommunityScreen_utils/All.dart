import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';

String _timeAgo(String createdAt) {
  final created = DateTime.tryParse(createdAt) ?? DateTime.now();
  final diff = DateTime.now().difference(created);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}

class All extends StatefulWidget {
  final int selectedTabIndex;
  final List<Post> posts;

  const All({super.key, required this.selectedTabIndex, required this.posts});

  @override
  State<All> createState() => _AllState();
}

class _AllState extends State<All> {
  String _selectedFilter = "Newest";

  List<Post> _filteredPosts() {
    List<Post> base;
    switch (widget.selectedTabIndex) {
      case 1:
        base = widget.posts
            .where((p) => p.category == PostCategory.general)
            .toList();
        break;
      case 2:
        base = widget.posts
            .where((p) => p.category == PostCategory.analysis)
            .toList();
        break;
      case 3:
        base =
            widget.posts.where((p) => p.category == PostCategory.news).toList();
        break;
      default:
        base = List.of(widget.posts);
    }

    switch (_selectedFilter) {
      case "Newest":
        base.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      // Popular / Best: placeholder — wire up likes count when available
      default:
        break;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredPosts();
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // 🔘 Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            children: [
              _buildFilterChip("Newest"),
              _buildFilterChip("Popular"),
              _buildFilterChip("Best"),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Ground Rules button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: () {
              showGroundRulesModal(context); // We'll define this next
            },
            child: Container(
              key: const ValueKey('community-ground-rules-card'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.lightGrey : AppPalette.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.push_pin_outlined,
                    color: colors.onSurface,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Community Ground Rules",
                      style: Heading5.style.copyWith(color: colors.onSurface),
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

        // Post list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: posts.length,
            itemBuilder: (context, index) => _buildPostCard(posts[index]),
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(height: 1, color: appColors.divider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        key: ValueKey('community-filter-${label.toLowerCase()}'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? AppPalette.white : const Color(0xFF272828))
              : AppPalette.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x26090A0A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Text(
          label.toUpperCase(),
          style: Body2_b.style.copyWith(
            color: isDark
                ? (isSelected ? AppPalette.black : AppPalette.white)
                : colors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    final hasMedia = post.mediaUrl != null;
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            isLight ? AppPalette.lightGrey : Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("User ${post.userId}", style: Body1.style),
                          Text(
                            _timeAgo(post.createdAt),
                            style: Body2.style
                                .copyWith(color: appColors.mutedForeground),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(post.title, style: Body1_b.style),
                  const SizedBox(height: 4),

                  Text(
                    post.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Body2.style,
                  ),
                  const SizedBox(height: 8),

                  // Like count (placeholder until likes are wired)
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_alt_outlined,
                        color: colors.onSurface,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text("—", style: Body2.style),
                    ],
                  ),
                ],
              ),
            ),

            // Right: media thumbnail
            if (hasMedia) ...[
              const SizedBox(width: 16),
              Builder(
                builder: (context) {
                  final size = MediaQuery.of(context).size.width * 0.4;
                  return Container(
                    width: size * 0.8,
                    height: size,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        post.mediaUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/highlight1.png',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
