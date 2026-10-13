import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  FakeVideoPlatform({this.initializationError, this.autoInitialize = true});

  final Object? initializationError;
  final bool autoInitialize;
  final streams = <int, StreamController<VideoEvent>>{};
  final playing = <int>{};
  final sources = <DataSource>[];
  final disposed = <int>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    sources.add(dataSource);
    final id = streams.length;
    final stream = StreamController<VideoEvent>();
    streams[id] = stream;
    if (initializationError != null) {
      stream.addError(initializationError!);
    } else if (autoInitialize) {
      stream.add(VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(292, 292),
        duration: const Duration(seconds: 8),
      ));
    }
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
    disposed.add(playerId);
    await streams[playerId]?.close();
  }
}
