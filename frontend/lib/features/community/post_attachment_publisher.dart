import 'package:cross_file/cross_file.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/features/media/video_encoder.dart';
import 'package:onetouch/models/uploaded_post_attachment.dart';

final class VideoUploadException implements Exception {
  const VideoUploadException(this.cause);

  final Object cause;
}

class PostAttachmentPublisher {
  const PostAttachmentPublisher({
    required PostRepository postRepository,
    required PostAttachmentRepository attachmentRepository,
    VideoEncoder? videoEncoder,
  })  : _postRepository = postRepository,
        _attachmentRepository = attachmentRepository,
        _videoEncoder = videoEncoder;

  final PostRepository _postRepository;
  final PostAttachmentRepository _attachmentRepository;
  final VideoEncoder? _videoEncoder;

  Future<int> publish({
    required CreatePostInput post,
    required List<XFile> mediaFiles,
    void Function(int sentBytes, int totalBytes, int fileIndex)?
        onUploadProgress,
    void Function(double fraction, int fileIndex)? onEncodingProgress,
    void Function(double fraction, int fileIndex)? onVerificationProgress,
    void Function()? onSaving,
  }) async {
    if (post.attachmentIds.isNotEmpty) {
      throw ArgumentError.value(
        post.attachmentIds,
        'post.attachmentIds',
        'must be empty before local media is uploaded',
      );
    }
    if (mediaFiles.length > 10) {
      throw RangeError.range(mediaFiles.length, 0, 10, 'mediaFiles.length');
    }

    return withUploadedAttachments<int>(
        mediaFiles: mediaFiles,
        onUploadProgress: onUploadProgress,
        onEncodingProgress: onEncodingProgress,
        onVerificationProgress: onVerificationProgress,
        onSaving: onSaving,
        save: (ids) => _postRepository.createPost(CreatePostInput(
            teamId: post.teamId,
            language: post.language,
            category: post.category,
            title: post.title,
            body: post.body,
            attachmentIds: ids)));
  }

  // 새 글·수정·임시저장은 업로드와 실패 시 정리 규칙이 같아요.
  Future<T> withUploadedAttachments<T>(
      {required List<XFile> mediaFiles,
      List<int> existingIds = const [],
      void Function(int sentBytes, int totalBytes, int fileIndex)?
          onUploadProgress,
      void Function(double fraction, int fileIndex)? onEncodingProgress,
      void Function(double fraction, int fileIndex)? onVerificationProgress,
      void Function()? onSaving,
      required Future<T> Function(List<int>) save}) async {
    final uploadedAttachmentIds = <int>[];
    final encodedVideos = <EncodedVideo>[];
    try {
      final filesForUpload = List<XFile>.from(mediaFiles);
      for (final (index, source) in mediaFiles.indexed) {
        final path = source.path.toLowerCase();
        final isVideo = source.mimeType?.startsWith('video/') == true ||
            path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.webm');
        if (!isVideo) continue;
        final encoder = _videoEncoder;
        if (encoder == null) {
          throw VideoUploadException(
              StateError('A video encoder is required for video attachments.'));
        }
        late final EncodedVideo encoded;
        try {
          encoded = await encoder.encode(source,
              onProgress: (fraction) =>
                  onEncodingProgress?.call(fraction, index),
              onVerificationProgress: (fraction) =>
                  onVerificationProgress?.call(fraction, index));
        } on Object catch (error) {
          throw VideoUploadException(error);
        }
        encodedVideos.add(encoded);
        filesForUpload[index] = encoded.file;
      }
      final lengths =
          await Future.wait(filesForUpload.map((file) => file.length()));
      final totalBytes = lengths.fold<int>(0, (sum, length) => sum + length);
      var completedBytes = 0;
      if (totalBytes > 0) onUploadProgress?.call(0, totalBytes, 0);
      for (final (index, file) in filesForUpload.indexed) {
        final byteLength = lengths[index];
        late final UploadedPostAttachment uploaded;
        try {
          uploaded = await _attachmentRepository.upload(
              content: file.openRead(),
              byteLength: byteLength,
              filename: file.name.trim().isEmpty
                  ? 'post-attachment-${index + 1}'
                  : file.name,
              onProgress: (sent, _) => onUploadProgress?.call(
                  completedBytes + sent, totalBytes, index));
        } on Object catch (error) {
          if (file.mimeType?.startsWith('video/') == true) {
            throw VideoUploadException(error);
          }
          rethrow;
        }
        uploadedAttachmentIds.add(uploaded.attachmentId);
        completedBytes += byteLength;
      }
      onSaving?.call();
      return await save([...existingIds, ...uploadedAttachmentIds]);
    } on Object {
      await _deleteUnpublishedAttachments(uploadedAttachmentIds);
      rethrow;
    } finally {
      for (final media in encodedVideos) {
        await media.dispose();
      }
    }
  }

  Future<void> _deleteUnpublishedAttachments(
    Iterable<int> attachmentIds,
  ) async {
    for (final attachmentId in attachmentIds.toList().reversed) {
      try {
        await _attachmentRepository.delete(attachmentId);
      } on Object {
        // 원래 저장 오류를 전달해요. 정리하지 못한 미사용 파일은 서버에서도 만료돼요.
      }
    }
  }
}
