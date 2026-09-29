import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/WelcomeScreen.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/theme_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _FakeVideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final playing = <int>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = streams.length;
    final stream = StreamController<VideoEvent>();
    streams[id] = stream;
    stream.add(VideoEvent(
      eventType: VideoEventType.initialized,
      size: const Size(292, 292),
      duration: const Duration(seconds: 8),
    ));
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {
    playing.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    playing.remove(playerId);
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) =>
      SizedBox.expand(key: ValueKey('video-$playerId'));

  @override
  Future<void> dispose(int playerId) async {
    await streams[playerId]?.close();
  }
}

void main() {
  testWidgets('theme and both warmed video layers fade from the same toggle',
      (tester) async {
    final originalPlatform = VideoPlayerPlatform.instance;
    final fakePlatform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
    final originalMode = appThemeController.value;
    appThemeController.value = ThemeMode.dark;
    addTearDown(() => appThemeController.value = originalMode);

    await tester.pumpWidget(ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeController,
      builder: (_, mode, __) => MaterialApp(
        theme: app_style.whitetheme,
        darkTheme: app_style.darktheme,
        themeMode: mode,
        home: const WelcomeScreen(),
      ),
    ));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    expect(fakePlatform.playing, {0, 1});
    expect(find.byType(VideoPlayer), findsNWidgets(2));
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        app_style.AppPalette.black);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('welcome-light-video-layer')),
          )
          .opacity,
      0.005,
    );

    appThemeController.value = ThemeMode.light;
    await tester.pump();
    expect(fakePlatform.playing, {0, 1});
    expect(find.byType(VideoPlayer), findsNWidgets(2));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('welcome-light-video-layer')),
          )
          .opacity,
      0.995,
    );
    await tester.pump(kThemeAnimationDuration ~/ 2);
    final halfwayColor =
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
    final halfwayVideoOpacity = tester
        .renderObject<RenderAnimatedOpacity>(
          find.byKey(const ValueKey('welcome-light-video-layer')),
        )
        .opacity
        .value;
    expect(halfwayColor, isNot(app_style.AppPalette.black));
    expect(halfwayColor, isNot(app_style.AppPalette.white));
    expect(halfwayVideoOpacity, greaterThan(0.005));
    expect(halfwayVideoOpacity, lessThan(0.995));

    await tester.pump(kThemeAnimationDuration ~/ 2);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        app_style.AppPalette.white);
    expect(fakePlatform.streams.length, 2);

    appThemeController.value = ThemeMode.dark;
    await tester.pump();
    await tester.pump(kThemeAnimationDuration);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        app_style.AppPalette.black);
    expect(fakePlatform.playing, {0, 1});
    expect(fakePlatform.streams.length, 2);
    expect(tester.takeException(), isNull);
  });
}
