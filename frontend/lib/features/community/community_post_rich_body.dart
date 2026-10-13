import 'package:flutter/material.dart';
import 'package:onetouch/core/web_links.dart';
import 'package:onetouch/data/link_previews/link_preview_repository.dart';
import 'package:onetouch/features/community/community_link_preview.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/models/post.dart';

typedef CommunityPostPart = ({String text, Uri? uri});

List<CommunityPostPart> communityPostParts(Post post) {
  final parts = <CommunityPostPart>[];
  final bodyLinks = webLinks(post.body).toList();
  var cursor = 0;
  void addText(String text) {
    if (text.trim().isNotEmpty) parts.add((text: text.trim(), uri: null));
  }

  for (final (start, end, uri) in bodyLinks) {
    addText(post.body.substring(cursor, start));
    parts.add((text: post.body.substring(start, end), uri: uri));
    cursor = end;
  }
  addText(post.body.substring(cursor));
  final seen = bodyLinks.map((link) => link.$3).toSet();
  for (final attachment in post.attachments) {
    final uri = webUri(attachment.linkUrl ?? '');
    // 같은 링크가 본문과 기존 첨부 데이터에 함께 있어도 카드는 한 번만 보여요.
    if (uri != null && seen.add(uri)) {
      parts.add((text: attachment.linkUrl!, uri: uri));
    }
  }
  return parts;
}

class CommunityPostRichBody extends StatelessWidget {
  const CommunityPostRichBody(
      {super.key, required this.parts, this.repository});
  final List<CommunityPostPart> parts;
  final LinkPreviewRepository? repository;

  @override
  Widget build(BuildContext context) {
    Widget? following;
    for (var i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      if (part.uri != null) {
        // 높이를 모르는 링크 아래 본문은 카드가 준비된 뒤 제자리에서 함께 보여요.
        following = CommunityLinkPreview(
            key: ValueKey((i, part.uri)),
            uri: part.uri!,
            repository: repository,
            followingContent: following);
      } else {
        following = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            CommunityLinkedText(
                text: part.text, style: CommunityText.body(context)),
            if (following != null) ...[const SizedBox(height: 24), following],
          ],
        );
      }
    }
    return following ?? const SizedBox.shrink();
  }
}
