import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/community_media.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/features/community/community_engagement.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/features/community/community_delete_dialog.dart';
import 'package:onetouch/features/community/community_post_share_link.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ground_rules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/report_dialog.dart';
import 'package:onetouch/l10n/app_localizations.dart';

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
    this.currentUserId,
    this.showMedia = true,
    this.mediaLoading = false,
    this.mediaLoadFailed = false,
    this.onRetryMedia,
    this.onEditPost,
    this.onDeletePost,
    this.onEditComment,
    this.onDeleteComment,
    this.shareInvoker,
    this.onLikeComment,
    this.onReportComment,
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
  final Future<void> Function(String reason)? onReport;
  final int? currentUserId;
  final bool showMedia;
  final bool mediaLoading;
  final bool mediaLoadFailed;
  final VoidCallback? onRetryMedia;
  final VoidCallback? onEditPost;
  final VoidCallback? onDeletePost;
  final ValueChanged<PostComment>? onEditComment;
  final ValueChanged<PostComment>? onDeleteComment;
  final ValueChanged<PostComment>? onLikeComment;
  final Future<void> Function(PostComment, String)? onReportComment;
  final Future<ShareResult> Function(ShareParams params)? shareInvoker;

  Future<void> _sharePost(BuildContext context) async {
    final renderBox = context.findRenderObject();
    final shareOrigin = renderBox is RenderBox && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : null;
    final params = ShareParams(
      title: '1touch',
      subject: post.title,
      uri: communityPostShareUri(post.postId),
      sharePositionOrigin: shareOrigin,
    );

    try {
      await (shareInvoker ?? SharePlus.instance.share)(params);
    } catch (error, stackTrace) {
      debugPrint('Community post share failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Unable to share post. Please try again.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final hasMedia =
        showMedia && !post.isDeleted && post.mediaAttachments.isNotEmpty;
    final showMediaStatus = showMedia &&
        post.attachments.isNotEmpty &&
        (mediaLoading || mediaLoadFailed);

    return SliverList(
      delegate: SliverChildListDelegate(
        [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: CommunityGroundRulesCard(
              cardKey: const ValueKey('community-detail-ground-rules-card'),
              onTap: () => showGroundRulesModal(context,
                  teamId: post.teamId, repository: communityRepository),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                    builder: (headerContext) => CommunityAuthorHeader(
                        userId: post.userId,
                        username: post.username,
                        displayName: post.displayName,
                        avatarUrl: post.avatarUrl,
                        authorDeleted: post.authorDeleted,
                        createdAt: post.createdAt,
                        editedAt: post.editedAt,
                        avatarKey:
                            ValueKey('community-post-avatar-${post.postId}'),
                        trailing: !post.isDeleted &&
                                currentUserId != null &&
                                post.userId == currentUserId
                            ? CommunityAuthorMenu(
                                key: const ValueKey(
                                    'community-post-delete-menu'),
                                boundaryContext: headerContext,
                                onEdit: onEditPost,
                                onDelete: onDeletePost)
                            : null)),
                const SizedBox(height: 12),
                if (post.isDeleted)
                  Text(tr(context, 'This post was deleted.'),
                      style: CommunityText.body(context)
                          .copyWith(color: appColors.mutedForeground))
                else ...[
                  Text(post.title, style: CommunityText.title(context)),
                  const SizedBox(height: 8),
                  CommunityLinkedText(
                      text: post.body,
                      showLinkIcons: true,
                      style: CommunityText.body(context)),
                  for (final attachment
                      in post.attachments.where((a) => a.linkUrl != null))
                    CommunityLinkedText(
                        text: attachment.linkUrl!,
                        showLinkIcons: true,
                        style: CommunityText.body(context)),
                ],
                const SizedBox(height: 28),
                if (showMediaStatus)
                  _PostMediaStatus(
                    isLoading: mediaLoading,
                    onRetry: onRetryMedia,
                  )
                else if (hasMedia)
                  CommunityMediaGrid(attachments: post.mediaAttachments),
                if (showMediaStatus || hasMedia) const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PostAction(
                      actionKey: const ValueKey(
                        'community-detail-like-action',
                      ),
                      icon: 'like',
                      selected: liked,
                      label: formatCommunityEngagementCount(likeCount),
                      labelKey: const ValueKey(
                        'community-detail-like-count',
                      ),
                      color: colors.onSurface,
                      onTap: onLike,
                    ),
                    _PostAction(
                      icon: 'comment',
                      label: formatCommunityEngagementCount(
                        commentCount,
                      ),
                      labelKey: const ValueKey(
                        'community-detail-comment-count',
                      ),
                      color: colors.onSurface,
                    ),
                    Builder(
                      builder: (shareContext) => _PostAction(
                        actionKey: const ValueKey(
                          'community-detail-share-action',
                        ),
                        icon: 'share',
                        label: 'Share',
                        color: colors.onSurface,
                        onTap: () => _sharePost(shareContext),
                      ),
                    ),
                    _PostAction(
                      icon: 'report',
                      label: 'Report',
                      color: colors.onSurface,
                      onTap: onReport == null
                          ? null
                          : () => showReportDialog(
                                context,
                                onSubmit: onReport!,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _PostComments(
            comments: comments,
            isLoading: commentsLoading,
            error: commentsError,
            onRetry: onRetryComments,
            onReply: onReply,
            currentUserId: currentUserId,
            onEditComment: onEditComment,
            onDeleteComment: onDeleteComment,
            onLikeComment: onLikeComment,
            onReportComment: onReportComment,
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
    this.editingTarget,
    required this.onCancelReply,
    this.onCancelEdit,
    required this.onSubmit,
  });

  final PostComment? replyTarget;
  final PostComment? editingTarget;
  final VoidCallback onCancelReply;
  final VoidCallback? onCancelEdit;
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
    if (widget.editingTarget?.commentId != oldWidget.editingTarget?.commentId) {
      _controller.text = widget.editingTarget?.body ?? '';
      if (widget.editingTarget != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }
    }
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
    final editing = widget.editingTarget != null;
    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(body);
      if (!mounted) return;
      _controller.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
              context,
              editing
                  ? 'Unable to update comment. Please try again.'
                  : 'Unable to post comment. Please try again.')),
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
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTarget != null || widget.editingTarget != null) ...[
              Row(
                key: const ValueKey('community-reply-target'),
                children: [
                  Expanded(
                    child: Text(
                      widget.editingTarget != null
                          ? tr(context, 'Edit comment')
                          : tr(context, 'Replying to {name}', {
                              'name': _commentAuthorLabel(
                                  context, widget.replyTarget!)
                            }),
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
                    onTap: _isSubmitting
                        ? null
                        : widget.editingTarget != null
                            ? widget.onCancelEdit
                            : widget.onCancelReply,
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
                      borderRadius: BorderRadius.circular(16),
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
                        hintText: widget.editingTarget != null
                            ? tr(context, 'Edit comment')
                            : widget.replyTarget == null
                                ? tr(context, 'Write a comment...')
                                : tr(context, 'Write a reply...'),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        hintStyle: CommunityText.body(context)
                            .copyWith(color: appColors.mutedForeground),
                        border: InputBorder.none,
                        filled: false,
                      ),
                      style: CommunityText.body(context)
                          .copyWith(color: colors.onSurface),
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
                    width: 43,
                    height: 43,
                    child: _isSubmitting
                        ? const CircularProgressIndicator(
                            key: ValueKey('community-comment-submitting'),
                            strokeWidth: 2,
                          )
                        : const CommunityIcon('send',
                            size: 43, originalColors: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.color,
    this.selected = false,
    this.actionKey,
    this.labelKey,
    this.onTap,
  });

  final String icon;
  final bool selected;
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
          padding: EdgeInsets.zero,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommunityIcon(icon,
                    size: icon == 'comment' ? 20 : 24,
                    color: selected ? const Color(0xFF5C92FF) : color),
                const SizedBox(width: 4),
                Text(tr(context, label),
                    key: labelKey, style: CommunityText.body(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostMediaStatus extends StatelessWidget {
  const _PostMediaStatus({required this.isLoading, required this.onRetry});

  final bool isLoading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: Center(
            child: isLoading
                ? CircularProgressIndicator(
                    key: const ValueKey('community-detail-media-loading'),
                    semanticsLabel: tr(context, 'Loading…'),
                  )
                : Column(
                    key: const ValueKey('community-detail-media-error'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr(context,
                            'Unable to load updated post. Please try again.'),
                        textAlign: TextAlign.center,
                        style: Body2.style,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('community-detail-media-retry'),
                        onPressed: onRetry,
                        child: Text(tr(context, 'Retry')),
                      ),
                    ],
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
    required this.currentUserId,
    required this.onEditComment,
    required this.onDeleteComment,
    required this.onLikeComment,
    required this.onReportComment,
  });

  final List<PostComment> comments;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<PostComment>? onReply;
  final int? currentUserId;
  final ValueChanged<PostComment>? onEditComment;
  final ValueChanged<PostComment>? onDeleteComment;
  final ValueChanged<PostComment>? onLikeComment;
  final Future<void> Function(PostComment, String)? onReportComment;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: FootballLoadingIndicator(
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
                tr(context, 'Unable to load comments.'),
                key: const ValueKey('community-comments-error'),
                style: Body2.style,
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('community-comments-retry'),
                onPressed: onRetry,
                child: Text(trUpper(context, 'Retry')),
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
          tr(context, 'No comments yet.'),
          key: const ValueKey('community-comments-empty'),
          style: Body2.style,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < comments.length; index++) ...[
            // 댓글 묶음은 48, 같은 묶음의 답글은 24만큼 띄워요.
            if (index > 0)
              SizedBox(height: comments[index].replyToId == null ? 48 : 24),
            _PostCommentRow(
              comment: comments[index],
              isDark: isDark,
              onReply: onReply,
              currentUserId: currentUserId,
              onEditComment: onEditComment,
              onDeleteComment: onDeleteComment,
              onLikeComment: onLikeComment,
              onReportComment: onReportComment,
            ),
          ],
        ],
      ),
    );
  }
}

class _PostCommentRow extends StatelessWidget {
  const _PostCommentRow({
    required this.comment,
    required this.isDark,
    required this.onReply,
    required this.currentUserId,
    required this.onEditComment,
    required this.onDeleteComment,
    required this.onLikeComment,
    required this.onReportComment,
  });

  final PostComment comment;
  final bool isDark;
  final ValueChanged<PostComment>? onReply;
  final int? currentUserId;
  final ValueChanged<PostComment>? onEditComment;
  final ValueChanged<PostComment>? onDeleteComment;
  final ValueChanged<PostComment>? onLikeComment;
  final Future<void> Function(PostComment, String)? onReportComment;

  @override
  Widget build(BuildContext context) {
    final active = comment.state == PostCommentState.active;
    final own = currentUserId != null && comment.userId == currentUserId;
    final reply = comment.replyToId != null;
    return Padding(
      padding: EdgeInsets.zero,
      child: CommunityReplyIndent(
          enabled: reply,
          child: Column(
              key: ValueKey('community-comment-${comment.commentId}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommunityAuthorHeader(
                    userId: comment.userId,
                    username: comment.username,
                    displayName: comment.state == PostCommentState.hidden ||
                            comment.state == PostCommentState.blocked
                        ? _commentAuthorLabel(context, comment)
                        : comment.displayName,
                    avatarUrl: comment.avatarUrl,
                    authorDeleted: comment.state == PostCommentState.hidden ||
                            comment.state == PostCommentState.blocked
                        ? false
                        : comment.authorDeleted,
                    createdAt: comment.createdAt,
                    editedAt: comment.editedAt,
                    avatarKey: ValueKey(
                        'community-comment-avatar-${comment.commentId}')),
                const SizedBox(height: 8),
                Text(_commentBodyLabel(context, comment),
                    style: CommunityText.body(context).copyWith(
                        color: active
                            ? null
                            : AppColors.of(context).mutedForeground)),
                if (active || comment.state == PostCommentState.deleted) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    GestureDetector(
                        key: active
                            ? ValueKey(
                                'community-comment-like-${comment.commentId}')
                            : null,
                        behavior: HitTestBehavior.opaque,
                        onTap: !active || onLikeComment == null
                            ? null
                            : () => onLikeComment!(comment),
                        child: Row(children: [
                          CommunityIcon('like',
                              color: comment.liked
                                  ? const Color(0xFF5C92FF)
                                  : null),
                          const SizedBox(width: 4),
                          Text(
                              formatCommunityEngagementCount(comment.likeCount),
                              style: CommunityText.body(context))
                        ])),
                    const SizedBox(width: 16),
                    GestureDetector(
                        key: active
                            ? ValueKey(
                                'community-comment-reply-${comment.commentId}')
                            : null,
                        onTap: !active || onReply == null
                            ? null
                            : () => onReply!(comment),
                        child: const CommunityIcon('reply')),
                    const SizedBox(width: 16),
                    CommunityAuthorMenu(
                        key: ValueKey(
                            'community-comment-${own ? 'delete' : 'menu'}-${comment.commentId}'),
                        boundaryContext: context,
                        onEdit: active && own && onEditComment != null
                            ? () => onEditComment!(comment)
                            : null,
                        onDelete: active && own && onDeleteComment != null
                            ? () => onDeleteComment!(comment)
                            : null,
                        onReport: active && !own && onReportComment != null
                            ? () => showReportDialog(context,
                                targetLabel: 'comment',
                                onSubmit: (reason) =>
                                    onReportComment!(comment, reason))
                            : null,
                        onCopy: !active
                            ? null
                            : () => Clipboard.setData(
                                ClipboardData(text: comment.body))),
                  ]),
                ],
              ])),
    );
  }
}

String _commentAuthorLabel(BuildContext context, PostComment comment) {
  return switch (comment.state) {
    PostCommentState.active || PostCommentState.deleted => communityAuthorLabel(
        locale: Localizations.localeOf(context),
        username: comment.username,
        displayName: comment.displayName,
        authorDeleted: comment.authorDeleted,
      ),
    PostCommentState.hidden => tr(context, 'Hidden comment'),
    PostCommentState.blocked => tr(context, 'Blocked user'),
  };
}

String _commentBodyLabel(BuildContext context, PostComment comment) {
  return switch (comment.state) {
    PostCommentState.active => comment.body,
    PostCommentState.deleted => tr(context, 'This comment was deleted.'),
    PostCommentState.hidden => tr(context, 'This comment is unavailable.'),
    PostCommentState.blocked => tr(context, 'Comment from a blocked user.'),
  };
}
