import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:onetouch/core/api_image_headers.dart';

class AvatarImageCache {
  AvatarImageCache._();

  static BaseCacheManager manager = CacheManager(Config(
    'profile-avatars-v1',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 300,
  ));
  static final _providers = <CachedNetworkImageProvider>{};

  static CachedNetworkImageProvider provider(String url,
      {Map<String, String>? headers}) {
    final uri = Uri.parse(url);
    final thumbnail = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'thumbnail': 'true',
    }).toString();
    final requestHeaders = headers ?? apiImageHeaders(url);
    // 같은 사진 URL도 로그인 세션별로 나누고, 토큰 원문은 캐시 키에 남기지 않아요.
    final session = requestHeaders?['Authorization'] ?? '';
    final key = sha256.convert(utf8.encode('$thumbnail\n$session')).toString();
    final image = CachedNetworkImageProvider(thumbnail,
        headers: requestHeaders, cacheKey: key, cacheManager: manager);
    _providers.add(image);
    return image;
  }

  static Future<void> evict(String url, {Map<String, String>? headers}) async {
    final image = provider(url, headers: headers);
    // 사진 변경·삭제 후에는 파일과 디코딩 캐시를 함께 비워요.
    await manager.removeFile(image.cacheKey!);
    await image.evict();
    _providers.remove(image);
  }

  static Future<void> clear() async {
    await manager.emptyCache();
    for (final image in _providers) {
      await image.evict();
    }
    _providers.clear();
  }
}
