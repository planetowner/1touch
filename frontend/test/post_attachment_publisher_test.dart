import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/features/community/post_attachment_publisher.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/uploaded_post_attachment.dart';

void main() {
  test('uploads local media and publishes its attachment IDs', () async {
    final attachments = _FakeAttachmentRepository();
    final posts = _RecordingPostRepository();
    final publisher = PostAttachmentPublisher(
      postRepository: posts,
      attachmentRepository: attachments,
    );

    final postId = await publisher.publish(
      post: _postInput(),
      mediaFiles: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode('first-image')),
          name: 'first.png',
        ),
        XFile.fromData(
          Uint8List.fromList(utf8.encode('second-image')),
          name: 'second.png',
        ),
      ],
    );

    expect(postId, 501);
    // In-memory XFiles expose no platform filename, so the publisher uses its
    // stable fallback. Device-picked files keep the native filename.
    expect(
      attachments.uploadedFilenames,
      ['post-attachment-1', 'post-attachment-2'],
    );
    expect(posts.createdInput?.attachmentIds, [101, 102]);
    expect(attachments.deletedIds, isEmpty);
  });

  test('deletes uploaded media when post creation fails', () async {
    final attachments = _FakeAttachmentRepository();
    final posts = _RecordingPostRepository(error: StateError('publish failed'));
    final publisher = PostAttachmentPublisher(
      postRepository: posts,
      attachmentRepository: attachments,
    );

    await expectLater(
      publisher.publish(
        post: _postInput(),
        mediaFiles: [
          XFile.fromData(Uint8List.fromList([1]), name: 'first.png'),
          XFile.fromData(Uint8List.fromList([2]), name: 'second.png'),
        ],
      ),
      throwsStateError,
    );

    expect(posts.createdInput?.attachmentIds, [101, 102]);
    expect(attachments.deletedIds, [102, 101]);
  });

  test('cleans up earlier uploads when a later upload fails', () async {
    final attachments = _FakeAttachmentRepository(failOnUpload: 2);
    final posts = _RecordingPostRepository();
    final publisher = PostAttachmentPublisher(
      postRepository: posts,
      attachmentRepository: attachments,
    );

    await expectLater(
      publisher.publish(
        post: _postInput(),
        mediaFiles: [
          XFile.fromData(Uint8List.fromList([1]), name: 'first.png'),
          XFile.fromData(Uint8List.fromList([2]), name: 'second.png'),
        ],
      ),
      throwsStateError,
    );

    expect(posts.createdInput, isNull);
    expect(attachments.deletedIds, [101]);
  });

  test('publishes text-only posts without attachment requests', () async {
    final attachments = _FakeAttachmentRepository();
    final posts = _RecordingPostRepository();
    final publisher = PostAttachmentPublisher(
      postRepository: posts,
      attachmentRepository: attachments,
    );

    await publisher.publish(post: _postInput(), mediaFiles: const []);

    expect(attachments.uploadedFilenames, isEmpty);
    expect(posts.createdInput?.attachmentIds, isEmpty);
  });
}

CreatePostInput _postInput() => CreatePostInput(
      teamId: 9,
      category: PostCategory.analysis,
      title: 'Match analysis',
      body: 'A detailed post.',
    );

class _FakeAttachmentRepository implements PostAttachmentRepository {
  _FakeAttachmentRepository({this.failOnUpload});

  final int? failOnUpload;
  final List<String> uploadedFilenames = [];
  final List<int> deletedIds = [];

  @override
  Future<UploadedPostAttachment> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    uploadedFilenames.add(filename);
    if (uploadedFilenames.length == failOnUpload) {
      throw StateError('upload failed');
    }
    final id = 100 + uploadedFilenames.length;
    return UploadedPostAttachment(
      attachmentId: id,
      contentType: 'image/png',
      byteSize: bytes.length,
    );
  }

  @override
  Future<void> delete(int attachmentId) async {
    deletedIds.add(attachmentId);
  }
}

class _RecordingPostRepository extends MockPostRepository {
  _RecordingPostRepository({this.error});

  final Object? error;
  CreatePostInput? createdInput;

  @override
  Future<int> createPost(CreatePostInput input) async {
    createdInput = input;
    final failure = error;
    if (failure != null) throw failure;
    return 501;
  }
}
