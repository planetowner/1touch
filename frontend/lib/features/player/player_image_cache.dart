import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class PlayerImageCache {
  PlayerImageCache._();

  static const double portraitSize = 160;

  static int decodeWidth(double size, double devicePixelRatio) =>
      (size * devicePixelRatio).ceil();

  // 선로딩과 화면 표시가 디코딩 크기까지 같아야 첫 프레임에 캐시를 써요.
  static ImageProvider portraitProvider(String url,
          {required double devicePixelRatio}) =>
      ResizeImage.resizeIfNeeded(
        decodeWidth(portraitSize, devicePixelRatio),
        null,
        CachedNetworkImageProvider(url.trim(), cacheManager: manager),
      );

  static final BaseCacheManager manager = CacheManager(
    Config(
      'player-images-v1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
    ),
  );
}
