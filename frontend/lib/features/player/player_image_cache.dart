import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class PlayerImageCache {
  PlayerImageCache._();

  static final BaseCacheManager manager = CacheManager(
    Config(
      'player-images-v1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
    ),
  );
}
