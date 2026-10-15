import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Object> registerDecodedPhoto(WidgetTester tester,
    DecodedPhotoCache cache, ImageProvider provider) async {
  final decoded = (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
        .drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = Colors.red);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    picture.dispose();
    return image;
  }))!;
  final key = await provider.obtainKey(ImageConfiguration.empty);
  cache.photos[key] = decoded;
  return key;
}

class DecodedPhotoTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => DecodedPhotoCache();
}

class DecodedPhotoCache extends ImageCache {
  final photos = <Object, ui.Image>{};
  final loads = <Object, int>{};

  @override
  ImageStreamCompleter? putIfAbsent(
      Object key, ImageStreamCompleter Function() loader,
      {ImageErrorListener? onError}) {
    final photo = photos[key];
    return super.putIfAbsent(
        key,
        photo == null
            ? loader
            : () {
                loads.update(key, (count) => count + 1, ifAbsent: () => 1);
                return OneFrameImageStreamCompleter(
                    SynchronousFuture(ImageInfo(image: photo.clone())));
              },
        onError: onError);
  }

  void reset() {
    clear();
    clearLiveImages();
    for (final photo in photos.values) {
      photo.dispose();
    }
    photos.clear();
    loads.clear();
  }
}
