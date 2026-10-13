import 'dart:io';

import 'package:cross_file/cross_file.dart';

class EncodedVideo {
  const EncodedVideo(this.file, {required this.isTemporary});

  final XFile file;
  final bool isTemporary;

  Future<void> dispose() async {
    if (!isTemporary) return;
    try {
      await File(file.path).delete();
    } on FileSystemException {
      // 업로드 결과나 원래 실패 원인을 임시 파일 정리 오류로 덮지 않아요.
    }
  }
}

abstract interface class VideoEncoder {
  Future<EncodedVideo> encode(
    XFile source, {
    void Function(double fraction)? onProgress,
    void Function(double fraction)? onVerificationProgress,
  });
}
