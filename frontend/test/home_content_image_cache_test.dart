import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/features/home/home_content_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('home image survives memory cache and cache manager recreation offline',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('home-image-cache-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    final bytes = await File('assets/highlight1.png').readAsBytes();
    var requests = 0;
    var offline = false;
    final client = MockClient((_) async {
      requests++;
      if (offline) throw const SocketException('offline');
      return http.Response.bytes(bytes, 200, headers: {
        'content-type': 'image/png',
        'cache-control': 'public, max-age=31536000, immutable',
        'etag': 'news-image',
      });
    });
    CacheManager createManager() => CacheManager(Config(
          'home-image-cache-test',
          repo: JsonCacheInfoRepository(path: '${directory.path}/cache.json'),
          fileService: HttpFileService(httpClient: client),
        ));

    var manager = createManager();
    CachedNetworkImageProvider.defaultCacheManager = manager;
    addTearDown(() async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await manager.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      client.close();
      await directory.delete(recursive: true);
    });

    const url = 'https://api.example.test/v1/news-images/image.webp';
    Future<void> resolveImage() async {
      final ready = Completer<void>();
      final stream =
          homeContentImageProvider(url).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((info, _) {
        expect(info.image.width, greaterThan(0));
        info.dispose();
        ready.complete();
      }, onError: ready.completeError);
      stream.addListener(listener);
      try {
        await ready.future;
      } finally {
        stream.removeListener(listener);
      }
    }

    await resolveImage();
    expect(requests, 1);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await manager.dispose();
    manager = createManager();
    CachedNetworkImageProvider.defaultCacheManager = manager;
    offline = true;

    await resolveImage();
    expect(requests, 1);
  });
}
