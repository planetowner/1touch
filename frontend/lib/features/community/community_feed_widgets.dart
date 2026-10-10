import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/features/community/community_engagement.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/features/community/community_media.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class CommunitySortFilters extends StatelessWidget {
  const CommunitySortFilters(
      {super.key, required this.selectedSort, required this.onChanged});
  final PostSort selectedSort;
  final ValueChanged<PostSort> onChanged;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (sort, label) in [
          (PostSort.newest, 'Newest'),
          (PostSort.popular, 'Popular'),
          (PostSort.best, 'Best')
        ])
          GestureDetector(
              onTap: () => onChanged(sort),
              child: AnimatedContainer(
                key: ValueKey(
                    'community-filter-${tr(context, label).toLowerCase()}'),
                duration: const Duration(milliseconds: 180),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: selectedSort == sort
                        ? appPillBackground(context, selected: true)
                        : Theme.of(context).brightness == Brightness.dark
                            ? AppPalette.darkGrey
                            : AppPalette.lightGreyBox,
                    borderRadius: BorderRadius.circular(16)),
                child: Center(
                  widthFactor: 1,
                  child: Text(trUpper(context, label),
                      style: Body2_b.style.copyWith(
                          color: appPillForeground(context,
                              selected: selectedSort == sort))),
                ),
              )),
      ]);
}

class CommunityGroundRulesCard extends StatelessWidget {
  const CommunityGroundRulesCard(
      {super.key,
      required this.onTap,
      this.cardKey = const ValueKey('community-ground-rules-card')});
  final VoidCallback onTap;
  final Key cardKey;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        key: cardKey,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppPalette.lightGrey
                : AppPalette.white,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const CommunityIcon('pin', size: 20),
          const SizedBox(width: 4),
          Expanded(
              child: Text(tr(context, 'Community Ground Rules'),
                  style: CommunityText.title(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis))
        ]),
      ));
}

class CommunityPostList extends StatelessWidget {
  const CommunityPostList(
      {super.key,
      required this.posts,
      required this.onPostTap,
      this.physics,
      this.bottomPadding = 0,
      this.header});
  final List<Post> posts;
  final ValueChanged<Post> onPostTap;
  final ScrollPhysics? physics;
  final double bottomPadding;
  final Widget? header;
  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: physics,
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
        itemCount: posts.length + (header == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (header != null && index == 0) return header!;
          final post = posts[index - (header == null ? 0 : 1)];
          return CommunityPostCard(post: post, onTap: () => onPostTap(post));
        },
        separatorBuilder: (context, index) => header != null && index == 0
            ? const SizedBox.shrink()
            : const CommunityPostSeparator(),
      );
}

class CommunityPostSeparator extends StatelessWidget {
  const CommunityPostSeparator({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 16),
        // Figma의 게시글 구분선(Line 92)은 실제 선 두께가 2예요.
        child: Divider(
            height: 2, thickness: 2, color: communityDividerColor(context)),
      );
}

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard(
      {super.key,
      required this.post,
      required this.onTap,
      this.bodyMaxLines = 2,
      this.showEngagement = true});
  final Post post;
  final VoidCallback onTap;
  final int bodyMaxLines;
  final bool showEngagement;
  @override
  Widget build(BuildContext context) {
    final media = post.isDeleted ? <PostAttachment>[] : post.mediaAttachments;
    // 목록의 제한된 줄 수를 빈 줄이 차지하지 않게 해요. 상세·수정 화면은 원문을 써요.
    final bodyPreview = post.body
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(builder: (context, constraints) {
          final mediaWidth = constraints.maxWidth * 119 / 345;
          return Stack(children: [
            Padding(
                padding:
                    EdgeInsets.only(right: media.isEmpty ? 0 : mediaWidth + 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CommunityAuthorHeader(
                          userId: post.userId,
                          username: post.username,
                          displayName: post.displayName,
                          avatarUrl: post.avatarUrl,
                          authorDeleted: post.authorDeleted,
                          createdAt: post.createdAt,
                          editedAt: post.editedAt,
                          avatarKey:
                              ValueKey('community-post-avatar-${post.postId}')),
                      const SizedBox(height: 4),
                      if (post.isDeleted)
                        Text(tr(context, 'This post was deleted.'),
                            style: CommunityText.body(context).copyWith(
                                color: AppColors.of(context).mutedForeground))
                      else ...[
                        Text(post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CommunityText.bold(context)),
                        const SizedBox(height: 4),
                        CommunityLinkedText(
                            text: bodyPreview,
                            maxLines: bodyMaxLines,
                            overflow: TextOverflow.ellipsis,
                            activateLinks: false,
                            showLinkIcons: true,
                            style: CommunityText.body(context)),
                        for (final attachment
                            in post.attachments.where((a) => a.linkUrl != null))
                          CommunityLinkedText(
                              text: attachment.linkUrl!,
                              maxLines: bodyMaxLines,
                              overflow: TextOverflow.ellipsis,
                              activateLinks: false,
                              showLinkIcons: true,
                              style: CommunityText.body(context)),
                      ],
                      if (showEngagement) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          const CommunityIcon('like'),
                          const SizedBox(width: 4),
                          Text(formatCommunityEngagementCount(post.likeCount),
                              key: ValueKey(
                                  'community-post-${post.postId}-like-count'),
                              style: CommunityText.body(context))
                        ]),
                      ],
                    ])),
            if (media.isNotEmpty)
              Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: mediaWidth,
                  child: GestureDetector(
                      key: ValueKey('community-post-${post.postId}-media-open'),
                      onTap: () => showCommunityAttachmentViewer(context,
                          mediaUrl: media.first.mediaUrl!, attachments: media),
                      child: CommunityMediaPreview(
                          attachment: media.first,
                          remaining: media.length - 1,
                          imageKey: ValueKey(
                              'community-post-${post.postId}-media')))),
          ]);
        }));
  }
}
