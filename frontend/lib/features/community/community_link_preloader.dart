import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/web_links.dart';
import 'package:onetouch/data/link_previews/link_preview_repository.dart';
import 'package:onetouch/features/community/community_social_embed_cache.dart';

void prepareCommunityLinks(BuildContext context, Iterable<Uri> links,
    {required double width, LinkPreviewRepository? repository}) {
  for (final uri in links.toSet()) {
    if (webLinkKind(uri) == WebLinkKind.website) {
      unawaited(
          _prepareWebsite(context, uri, repository ?? linkPreviewRepository));
    } else {
      communitySocialEmbedCache.prepare(uri,
          language: Localizations.localeOf(context).languageCode,
          isDark: Theme.of(context).brightness == Brightness.dark,
          width: width);
    }
  }
}

Future<void> _prepareWebsite(
    BuildContext context, Uri uri, LinkPreviewRepository repository) async {
  try {
    final data = await repository.load(uri);
    if (!context.mounted || data.imageUri == null) return;
    await precacheImage(
        CachedNetworkImageProvider(data.imageUri.toString()), context,
        onError: (_, __) {});
  } on Object {
    // 목록의 선로딩 실패는 상세에서 원문 링크와 재시도로 처리해요.
  }
}
