import 'package:flutter/foundation.dart';

@immutable
class UploadedPostAttachment {
  const UploadedPostAttachment({
    required this.attachmentId,
    required this.contentType,
    required this.byteSize,
  });

  final int attachmentId;
  final String contentType;
  final int byteSize;
}
