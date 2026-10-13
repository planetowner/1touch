import 'package:onetouch/models/uploaded_post_attachment.dart';

abstract interface class PostAttachmentRepository {
  Future<UploadedPostAttachment> upload({
    required Stream<List<int>> content,
    required int byteLength,
    required String filename,
    void Function(int sentBytes, int totalBytes)? onProgress,
  });

  Future<void> delete(int attachmentId);
}
