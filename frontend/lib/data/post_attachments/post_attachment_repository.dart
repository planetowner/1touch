import 'dart:typed_data';

import 'package:onetouch/models/uploaded_post_attachment.dart';

abstract interface class PostAttachmentRepository {
  Future<UploadedPostAttachment> upload({
    required Uint8List bytes,
    required String filename,
  });

  Future<void> delete(int attachmentId);
}
