import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:onetouch/features/media/video_encoder.dart';
import 'package:uuid/uuid.dart';

class PlatformVideoEncoder implements VideoEncoder {
  PlatformVideoEncoder() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('onetouch/video_encoder');
  static final _progressHandlers = <String, void Function(double)>{};
  static final _verificationHandlers = <String, void Function(double)>{};

  static Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'progress' && call.method != 'verificationProgress') {
      return;
    }
    final args = call.arguments;
    if (args is! Map) return;
    final jobId = args['jobId'];
    final fraction = args['fraction'];
    if (jobId is String && fraction is num) {
      final handler = call.method == 'progress'
          ? _progressHandlers[jobId]
          : _verificationHandlers[jobId];
      handler?.call(fraction.toDouble().clamp(0.0, 1.0));
    }
  }

  @override
  Future<EncodedVideo> encode(
    XFile source, {
    void Function(double fraction)? onProgress,
    void Function(double fraction)? onVerificationProgress,
  }) async {
    final jobId = const Uuid().v4();
    if (onProgress != null) _progressHandlers[jobId] = onProgress;
    if (onVerificationProgress != null) {
      _verificationHandlers[jobId] = onVerificationProgress;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'encode',
        <String, Object>{
          'jobId': jobId,
          'path': source.path,
        },
      );
      final path = result?['path'];
      final mimeType = result?['mimeType'];
      if (path is! String || path.isEmpty || mimeType is! String) {
        throw const FormatException('Invalid media encoder result.');
      }
      return EncodedVideo(
        XFile(path, mimeType: mimeType),
        isTemporary: path != source.path,
      );
    } finally {
      _progressHandlers.remove(jobId);
      _verificationHandlers.remove(jobId);
    }
  }
}
