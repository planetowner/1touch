import 'package:image_picker/image_picker.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';

class PostAttachmentPublisher {
  const PostAttachmentPublisher({
    required PostRepository postRepository,
    required PostAttachmentRepository attachmentRepository,
  })  : _postRepository = postRepository,
        _attachmentRepository = attachmentRepository;

  final PostRepository _postRepository;
  final PostAttachmentRepository _attachmentRepository;

  Future<int> publish({
    required CreatePostInput post,
    required List<XFile> mediaFiles,
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

    final uploadedAttachmentIds = <int>[];
    try {
      for (var index = 0; index < mediaFiles.length; index++) {
        final file = mediaFiles[index];
        final uploaded = await _attachmentRepository.upload(
          bytes: await file.readAsBytes(),
          filename: file.name.trim().isEmpty
              ? 'post-attachment-${index + 1}'
              : file.name,
        );
        uploadedAttachmentIds.add(uploaded.attachmentId);
      }

      return await _postRepository.createPost(
        CreatePostInput(
          teamId: post.teamId,
          category: post.category,
          title: post.title,
          body: post.body,
          attachmentIds: uploadedAttachmentIds,
        ),
      );
    } on Object {
      await _deleteUnpublishedAttachments(uploadedAttachmentIds);
      rethrow;
    }
  }

  Future<void> _deleteUnpublishedAttachments(
    Iterable<int> attachmentIds,
  ) async {
    for (final attachmentId in attachmentIds.toList().reversed) {
      try {
        await _attachmentRepository.delete(attachmentId);
      } on Object {
        // Cleanup is best-effort. The backend also expires unpublished files,
        // while callers still need the original upload or publish failure.
      }
    }
  }
}
