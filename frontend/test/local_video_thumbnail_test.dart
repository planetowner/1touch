import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/community/local_video_thumbnail.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_platform.dart';

void main() {
  late FakeVideoPlatform video;

  setUp(() {
    final original = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = original);
  });

  for (final size in [const Size(320, 640), const Size(430, 932)]) {
    testWidgets('local video thumbnail fits ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 100,
            child: LocalVideoThumbnail(path: '/tmp/first.mp4'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(video.sources.single.sourceType, DataSourceType.file);
      expect(video.sources.single.uri, 'file:///tmp/first.mp4');
      expect(find.byKey(const ValueKey('video-0')), findsOneWidget);
      expect(video.playing, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 100,
            child: LocalVideoThumbnail(path: '/tmp/second.mp4'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(video.sources.last.uri, 'file:///tmp/second.mp4');
      expect(find.byKey(const ValueKey('video-1')), findsOneWidget);
      expect(video.playing, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
