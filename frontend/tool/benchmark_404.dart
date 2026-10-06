import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:onetouch/core/app_error_config.dart';
import 'package:onetouch/core/style.dart' as style;
import 'package:onetouch/features/app_error_view.dart';
import 'package:onetouch/l10n/app_localizations.dart';

// 실제 화면을 그대로 측정하고, 앱 초기화나 서버 요청은 실행하지 않아요.
// flutter run --profile --no-pub -d <device-id> -t tool/benchmark_404.dart
void main() {
  if (!kProfileMode && !kReleaseMode) {
    throw StateError('Run this benchmark with --profile or --release.');
  }
  _BenchmarkBinding();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    theme: style.darktheme,
    home: const _BenchmarkScreen(),
  ));
}

final _asset = appErrorConfigFor(404).imageAsset!;
_Sample? _currentSample;

class _BenchmarkBinding extends WidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => _MeasuredImageCache();
}

class _MeasuredImageCache extends ImageCache {
  @override
  ImageStreamCompleter? putIfAbsent(
    Object key,
    ImageStreamCompleter Function() loader, {
    ImageErrorListener? onError,
  }) {
    final sample = _currentSample;
    final measuring = sample != null &&
        key is AssetBundleImageKey &&
        key.name == _asset &&
        sample.imageRequestedUs == null;
    if (measuring) {
      sample.imageRequestedUs = sample.clock.elapsedMicroseconds;
      sample.cacheHit = statusForKey(key).keepAlive;
    }
    final stream = super.putIfAbsent(key, loader, onError: onError);
    if (measuring && stream != null) {
      // 별도로 이미지를 resolve하면 미리 로딩될 수 있어 실제 요청을 관찰해요.
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, synchronous) {
        sample.imageReadyUs = sample.clock.elapsedMicroseconds;
        sample.imageWidth = info.image.width;
        sample.imageHeight = info.image.height;
        info.dispose();
        stream.removeListener(listener);
      }, onError: (error, stack) {
        stream.removeListener(listener);
        sample.done.completeError(error, stack);
      });
      stream.addListener(listener);
    }
    return stream;
  }
}

class _Sample {
  _Sample(this.condition, this.iteration)
      : startedWallUs = DateTime.now().microsecondsSinceEpoch;

  final String condition;
  final int iteration;
  final int startedWallUs;
  final clock = Stopwatch()..start();
  final done = Completer<void>();
  final observedFrames = <int>{};
  final timings = <int, ui.FrameTiming>{};
  int? firstFrame;
  int? photoFrame;
  int? firstUiUs;
  int? imageRequestedUs;
  int? imageReadyUs;
  int? imageWidth;
  int? imageHeight;
  bool? cacheHit;

  void recordTimings(List<ui.FrameTiming> frames) {
    for (final frame in frames) {
      if (observedFrames.contains(frame.frameNumber)) {
        timings[frame.frameNumber] = frame;
      }
    }
    if (!done.isCompleted &&
        timings.containsKey(firstFrame) &&
        timings.containsKey(photoFrame)) {
      done.complete();
    }
  }

  Map<String, Object?> toJson() {
    final first = timings[firstFrame]!;
    final photo = timings[photoFrame]!;
    final firstRasterUs =
        first.timestampInMicroseconds(ui.FramePhase.rasterFinishWallTime);
    final photoRasterUs =
        photo.timestampInMicroseconds(ui.FramePhase.rasterFinishWallTime);
    // 콜백 대기 시간을 빼기 위해 엔진이 기록한 완료 시각을 사용해요.
    // raster 완료는 화면 표시 준비의 기준이며, 패널에 표시된 순간은 아니에요.
    return {
      'condition': condition,
      'iteration': iteration,
      'cache_hit': cacheHit,
      'image_size': [imageWidth, imageHeight],
      'image_request_to_ready_ms': (imageReadyUs! - imageRequestedUs!) / 1000,
      'entry_to_image_ready_ms': imageReadyUs! / 1000,
      'entry_to_first_ui_paint_ms': firstUiUs! / 1000,
      'entry_to_first_raster_ms': (firstRasterUs - startedWallUs) / 1000,
      'entry_to_photo_raster_ms': (photoRasterUs - startedWallUs) / 1000,
      'photo_after_first_raster_ms': (photoRasterUs - firstRasterUs) / 1000,
      'photo_in_first_frame': photoFrame == firstFrame,
      'frames': timings.values
          .map((frame) => {
                'number': frame.frameNumber,
                'build_ms': frame.buildDuration.inMicroseconds / 1000,
                'raster_ms': frame.rasterDuration.inMicroseconds / 1000,
              })
          .toList(),
    };
  }
}

class _BenchmarkScreen extends StatefulWidget {
  const _BenchmarkScreen();

  @override
  State<_BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<_BenchmarkScreen> {
  final _errorKey = GlobalKey();
  final _results = <Map<String, Object?>>[];
  String _status = '404 PNG 측정을 준비하고 있어요';

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    binding.addTimingsCallback(_onTimings);
    binding.addPersistentFrameCallback((_) {
      final sample = _currentSample;
      if (sample == null) return;
      final frameNumber = ui.PlatformDispatcher.instance.frameData.frameNumber;
      binding.addPostFrameCallback((_) {
        final root = _errorKey.currentContext?.findRenderObject();
        if (root == null || !identical(sample, _currentSample)) return;
        sample.observedFrames.add(frameNumber);
        sample.firstFrame ??= frameNumber;
        sample.firstUiUs ??= sample.clock.elapsedMicroseconds;
        if (sample.photoFrame == null && _hasPhoto(root)) {
          sample.photoFrame = frameNumber;
        }
      });
    });
    binding.addPostFrameCallback((_) => _run());
  }

  bool _hasPhoto(RenderObject root) {
    if (root is RenderImage && root.image != null) return true;
    var found = false;
    root.visitChildren((child) {
      if (!found) found = _hasPhoto(child);
    });
    return found;
  }

  void _onTimings(List<ui.FrameTiming> frames) =>
      _currentSample?.recordTimings(frames);

  Future<void> _run() async {
    try {
      await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      final view = View.of(context);
      debugPrint('BENCH404_META ${jsonEncode({
            'os': Platform.operatingSystem,
            'os_version': Platform.operatingSystemVersion,
            'mode': kProfileMode ? 'profile' : 'release',
            'asset': _asset,
            'physical_size': [
              view.physicalSize.width,
              view.physicalSize.height
            ],
            'device_pixel_ratio': view.devicePixelRatio,
            'display_refresh_rate': view.display.refreshRate,
            'pairs': 10,
          })}');
      for (var iteration = 0; iteration < 10; iteration++) {
        // Flutter의 이미지 캐시만 비워요. OS 파일 캐시나 앱 데이터는 지우지 않아요.
        imageCache.clear();
        imageCache.clearLiveImages();
        await _measure(
            iteration == 0 ? 'first_use' : 'cache_cleared', iteration);
        await _measure('cached', iteration);
      }
      debugPrint('BENCH404_DONE ${jsonEncode({'samples': _results.length})}');
      setState(() => _status = '404 PNG 측정이 끝났어요\n터미널에서 결과를 확인해주세요');
    } catch (error, stack) {
      debugPrint('BENCH404_ERROR $error\n$stack');
      if (mounted) {
        setState(() {
          _currentSample = null;
          _status = '측정을 완료하지 못했어요\n$error';
        });
      }
    }
  }

  Future<void> _measure(String condition, int iteration) async {
    final sample = _Sample(condition, iteration);
    setState(() => _currentSample = sample);
    await sample.done.future.timeout(const Duration(seconds: 15));
    sample.clock.stop();
    final result = sample.toJson();
    if (sample.cacheHit != (condition == 'cached')) {
      throw StateError('Unexpected image cache state: $result');
    }
    _results.add(result);
    debugPrint('BENCH404_SAMPLE ${jsonEncode(result)}');
    setState(() => _currentSample = null);
    await WidgetsBinding.instance.endOfFrame;
    // 화면을 제거한 다음 캐시를 비워야 이전 Image의 참조가 남지 않아요.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _currentSample == null
      ? Scaffold(
          body: Center(child: Text(_status, textAlign: TextAlign.center)))
      : IgnorePointer(child: AppErrorScreen(key: _errorKey, statusCode: 404));
}
