import 'package:onetouch/l10n/date_labels.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/features/community/community_engagement.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class CommunitySortFilters extends StatelessWidget {
  const CommunitySortFilters({
    super.key,
    required this.selectedSort,
    required this.onChanged,
  });

  final PostSort selectedSort;
  final ValueChanged<PostSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        _SortChip(
          label: tr(context, 'Newest'),
          sort: PostSort.newest,
          isSelected: selectedSort == PostSort.newest,
          onTap: onChanged,
        ),
        _SortChip(
          label: tr(context, 'Popular'),
          sort: PostSort.popular,
          isSelected: selectedSort == PostSort.popular,
          onTap: onChanged,
        ),
        _SortChip(
          label: tr(context, 'Best'),
          sort: PostSort.best,
          isSelected: selectedSort == PostSort.best,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class CommunityGroundRulesCard extends StatelessWidget {
  const CommunityGroundRulesCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const ValueKey('community-ground-rules-card'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.lightGrey : AppPalette.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.push_pin_outlined, color: colors.onSurface, size: 20),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                tr(context, 'Community Ground Rules'),
                style: Heading5.style.copyWith(color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityPostList extends StatelessWidget {
  const CommunityPostList({
    super.key,
    required this.posts,
    required this.onPostTap,
  });

  final List<Post> posts;
  final ValueChanged<Post> onPostTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: posts.length,
      itemBuilder: (context, index) => _PostCard(
        post: posts[index],
        onTap: () => onPostTap(posts[index]),
      ),
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(height: 1, color: AppColors.of(context).divider),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.sort,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final PostSort sort;
  final bool isSelected;
  final ValueChanged<PostSort> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onTap(sort),
      child: Container(
        key: ValueKey('community-filter-${label.toLowerCase()}'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? AppPalette.white : AppPalette.lightGrey)
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
          tr(context, label).toUpperCase(),
          style: Body2_b.style.copyWith(
            color: isDark
                ? (isSelected ? AppPalette.black : AppPalette.white)
                : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMedia = post.mediaUrl != null;
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          Text(
                            communityUsernameLabel(
                              locale: Localizations.localeOf(context),
                              username: post.username,
                              authorDeleted: post.authorDeleted,
                            ),
                            style: Body1.style,
                          ),
                          Text(
                            _timeAgo(context, post.createdAt),
                            style: Body2.style.copyWith(
                              color: appColors.mutedForeground,
                            ),
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
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_alt_outlined,
                        color: colors.onSurface,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formatCommunityEngagementCount(post.likeCount),
                        key: ValueKey(
                          'community-post-${post.postId}-like-count',
                        ),
                        style: Body2.style,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasMedia) ...[
              const SizedBox(width: 16),
              Builder(
                builder: (context) {
                  final size = MediaQuery.sizeOf(context).width * 0.4;
                  return Container(
                    width: size * 0.8,
                    height: size,
                    decoration: BoxDecoration(
                      color: AppPalette.lightGrey,
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

String _timeAgo(BuildContext context, String createdAt) =>
    relativeTimeLabel(DateTime.tryParse(createdAt),
        locale: Localizations.localeOf(context));
