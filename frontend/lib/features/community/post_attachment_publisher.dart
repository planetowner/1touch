import 'package:cross_file/cross_file.dart';
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

    return withUploadedAttachments<int>(
        mediaFiles: mediaFiles,
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
      required Future<T> Function(List<int>) save}) async {
    final uploadedAttachmentIds = <int>[];
    try {
      for (final (index, file) in mediaFiles.indexed) {
        final uploaded = await _attachmentRepository.upload(
            bytes: await file.readAsBytes(),
            filename: file.name.trim().isEmpty
                ? 'post-attachment-${index + 1}'
                : file.name);
        uploadedAttachmentIds.add(uploaded.attachmentId);
      }
      return await save([...existingIds, ...uploadedAttachmentIds]);
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
        // 원래 저장 오류를 전달해요. 정리하지 못한 미사용 파일은 서버에서도 만료돼요.
      }
    }
  }
}
