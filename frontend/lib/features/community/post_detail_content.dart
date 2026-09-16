import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/features/community/community_engagement.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ReportDialog.dart';

class PostDetailContent extends StatelessWidget {
  const PostDetailContent({
    super.key,
    required this.post,
    required this.communityRepository,
    required this.onReport,
  });

  final Post post;
  final CommunityRepository communityRepository;
  final Future<void> Function(String reason) onReport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMedia = post.mediaUrl != null;

    return SliverList(
      delegate: SliverChildListDelegate(
        [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () => showGroundRulesModal(
                context,
                teamId: post.teamId,
                repository: communityRepository,
              ),
              child: Container(
                key: const ValueKey('community-detail-ground-rules-card'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Community Ground Rules',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor:
                          isDark ? Colors.white24 : AppPalette.lightGrey,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          communityUsernameLabel(
                            username: post.username,
                            authorDeleted: post.authorDeleted,
                          ),
                          style: Body1.style,
                        ),
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
                if (hasMedia) _PostMediaPreview(mediaUrl: post.mediaUrl!),
                if (hasMedia) const SizedBox(height: 16),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PostAction(
                      icon: Icons.thumb_up_alt_outlined,
                      label: formatCommunityEngagementCount(post.likeCount),
                      labelKey: const ValueKey(
                        'community-detail-like-count',
                      ),
                      color: colors.onSurface,
                    ),
                    _PostAction(
                      icon: Icons.mode_comment_outlined,
                      label: formatCommunityEngagementCount(
                        post.commentCount,
                      ),
                      labelKey: const ValueKey(
                        'community-detail-comment-count',
                      ),
                      color: colors.onSurface,
                    ),
                    _PostAction(
                      icon: Icons.share,
                      label: 'share',
                      color: colors.onSurface,
                    ),
                    _PostAction(
                      icon: Icons.report_gmailerrorred_outlined,
                      label: 'report',
                      color: colors.onSurface,
                      onTap: () => showReportDialog(
                        context,
                        onSubmit: onReport,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SampleComments(),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class PostDetailReplyBar extends StatelessWidget {
  const PostDetailReplyBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // TODO: Connect reply submission when the API supports comments/replies.
    return Container(
      color: isDark ? AppPalette.darkGrey : AppPalette.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color:
                    isDark ? AppPalette.lightGrey : appColors.subtleBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
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
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.color,
    this.labelKey,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Key? labelKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                Text(label, key: labelKey, style: Body2.style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostMediaPreview extends StatelessWidget {
  const _PostMediaPreview({required this.mediaUrl});

  final String mediaUrl;

  @override
  Widget build(BuildContext context) {
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

class _SampleComments extends StatelessWidget {
  const _SampleComments();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // TODO: Replace sample comments when the API provides comment threads.
    return Padding(
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
                  backgroundColor:
                      isDark ? Colors.white24 : AppPalette.lightGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Username', style: Body2_b.style),
                      Text(
                        'First sentence goes here. Second sentence goes here. Third sentence goes here.',
                        style: Body2.style,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.reply, size: 18, color: colors.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _timeAgo(String createdAt) {
  final created = DateTime.tryParse(createdAt) ?? DateTime.now();
  final diff = DateTime.now().difference(created);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}
