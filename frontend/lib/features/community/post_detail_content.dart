import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/features/community/community_engagement.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ReportDialog.dart';

class PostDetailContent extends StatelessWidget {
  const PostDetailContent({
    super.key,
    required this.post,
    required this.liked,
    required this.likeCount,
    required this.commentCount,
    required this.onLike,
    required this.communityRepository,
    required this.comments,
    required this.commentsLoading,
    required this.commentsError,
    required this.onRetryComments,
    required this.onReply,
    required this.onReport,
  });

  final Post post;
  final bool liked;
  final int likeCount;
  final int commentCount;
  final VoidCallback? onLike;
  final CommunityRepository communityRepository;
  final List<PostComment> comments;
  final bool commentsLoading;
  final Object? commentsError;
  final VoidCallback onRetryComments;
  final ValueChanged<PostComment>? onReply;
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
                      actionKey: const ValueKey(
                        'community-detail-like-action',
                      ),
                      icon: liked
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                      label: formatCommunityEngagementCount(likeCount),
                      labelKey: const ValueKey(
                        'community-detail-like-count',
                      ),
                      color: colors.onSurface,
                      onTap: onLike,
                    ),
                    _PostAction(
                      icon: Icons.mode_comment_outlined,
                      label: formatCommunityEngagementCount(
                        commentCount,
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
          _PostComments(
            comments: comments,
            isLoading: commentsLoading,
            error: commentsError,
            onRetry: onRetryComments,
            onReply: onReply,
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class PostDetailReplyBar extends StatefulWidget {
  const PostDetailReplyBar({
    super.key,
    required this.replyTarget,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final PostComment? replyTarget;
  final VoidCallback onCancelReply;
  final Future<void> Function(String body) onSubmit;

  @override
  State<PostDetailReplyBar> createState() => _PostDetailReplyBarState();
}

class _PostDetailReplyBarState extends State<PostDetailReplyBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  bool get _canSubmit => !_isSubmitting && _controller.text.trim().isNotEmpty;

  @override
  void didUpdateWidget(PostDetailReplyBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyTarget?.commentId != oldWidget.replyTarget?.commentId &&
        widget.replyTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final body = _controller.text.trim();
    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(body);
      if (!mounted) return;
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to post comment. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppPalette.darkGrey : AppPalette.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyTarget != null) ...[
            Row(
              key: const ValueKey('community-reply-target'),
              children: [
                Expanded(
                  child: Text(
                    'Replying to ${_commentAuthorLabel(widget.replyTarget!)}',
                    style: Body2.style.copyWith(
                      color: appColors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  key: const ValueKey('community-reply-cancel'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _isSubmitting ? null : widget.onCancelReply,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
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
                    key: const ValueKey('community-comment-input'),
                    controller: _controller,
                    focusNode: _focusNode,
                    readOnly: _isSubmitting,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        maxPostCommentBodyLength,
                      ),
                    ],
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: widget.replyTarget == null
                          ? 'Write a comment...'
                          : 'Write a reply...',
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
              GestureDetector(
                key: const ValueKey('community-comment-send'),
                behavior: HitTestBehavior.opaque,
                onTap: _canSubmit ? _submit : null,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          key: ValueKey('community-comment-submitting'),
                          strokeWidth: 2,
                        )
                      : const Icon(Icons.send, color: Colors.blueAccent),
                ),
              ),
            ],
          ),
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
    this.actionKey,
    this.labelKey,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Key? actionKey;
  final Key? labelKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        key: actionKey,
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

class _PostComments extends StatelessWidget {
  const _PostComments({
    required this.comments,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onReply,
  });

  final List<PostComment> comments;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<PostComment>? onReply;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(
            key: ValueKey('community-comments-loading'),
          ),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Text(
                'Unable to load comments.',
                key: const ValueKey('community-comments-error'),
                style: Body2.style,
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('community-comments-retry'),
                onPressed: onRetry,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          'No comments yet.',
          key: const ValueKey('community-comments-empty'),
          style: Body2.style,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: comments
            .map(
              (comment) => _PostCommentRow(
                comment: comment,
                isDark: isDark,
                onReply: onReply,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PostCommentRow extends StatelessWidget {
  const _PostCommentRow({
    required this.comment,
    required this.isDark,
    required this.onReply,
  });

  final PostComment comment;
  final bool isDark;
  final ValueChanged<PostComment>? onReply;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatarUrl = comment.avatarUrl;

    return Padding(
      padding: EdgeInsets.only(
        left: comment.replyToId == null ? 0 : 24,
        bottom: 16,
      ),
      child: Row(
        key: ValueKey('community-comment-${comment.commentId}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isDark ? Colors.white24 : AppPalette.lightGrey,
            backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_commentAuthorLabel(comment), style: Body2_b.style),
                Text(_commentBodyLabel(comment), style: Body2.style),
              ],
            ),
          ),
          if (comment.state == PostCommentState.active)
            GestureDetector(
              key: ValueKey('community-comment-reply-${comment.commentId}'),
              behavior: HitTestBehavior.opaque,
              onTap: onReply == null ? null : () => onReply!(comment),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.reply, size: 18, color: colors.onSurface),
              ),
            ),
        ],
      ),
    );
  }
}

String _commentAuthorLabel(PostComment comment) {
  return switch (comment.state) {
    PostCommentState.active => communityUsernameLabel(
        username: comment.username,
        authorDeleted: comment.authorDeleted,
      ),
    PostCommentState.deleted => 'Deleted comment',
    PostCommentState.hidden => 'Hidden comment',
    PostCommentState.blocked => 'Blocked user',
  };
}

String _commentBodyLabel(PostComment comment) {
  return switch (comment.state) {
    PostCommentState.active => comment.body,
    PostCommentState.deleted => 'This comment was deleted.',
    PostCommentState.hidden => 'This comment is unavailable.',
    PostCommentState.blocked => 'Comment from a blocked user.',
  };
}

String _timeAgo(String createdAt) {
  final created = DateTime.tryParse(createdAt) ?? DateTime.now();
  final diff = DateTime.now().difference(created);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}
