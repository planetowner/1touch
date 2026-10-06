import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_image_cache.dart';

void main() {
  testWidgets(
      'popup, detail and comparison reuse the decoded portrait on their first frame',
      (tester) async {
    const url = 'https://cdn.example/player.png';
    final provider = ResizeImage.resizeIfNeeded(
        320,
        null,
        CachedNetworkImageProvider(url,
            cacheManager: PlayerImageCache.manager));
    final key = await provider.obtainKey(ImageConfiguration.empty);
    final decoded = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = Colors.red);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      picture.dispose();
      return image;
    });
    PaintingBinding.instance.imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(
            SynchronousFuture(ImageInfo(image: decoded!))));
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });

    for (final dimensions in [(null, 140.0), (160.0, 160.0), (130.0, 128.0)]) {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Center(
            child: PlayerRemoteImage.portrait(
          url,
          key: ValueKey(dimensions),
          width: dimensions.$1,
          height: dimensions.$2,
          placeholder: const Text('Photo loading'),
        )),
      )));
      expect(find.text('Photo loading'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
