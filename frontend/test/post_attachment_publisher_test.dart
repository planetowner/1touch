import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/features/community/post_attachment_publisher.dart';
import 'package:onetouch/features/media/video_encoder.dart';
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

  test('reports encoding before uploaded byte progress', () async {
    final phases = <String>[];
    final publisher = PostAttachmentPublisher(
      postRepository: _RecordingPostRepository(),
      attachmentRepository: _FakeAttachmentRepository(),
      videoEncoder: _RecordingVideoEncoder(),
    );

    await publisher.publish(
      post: _postInput(),
      mediaFiles: [
        XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'video/mp4')
      ],
      onEncodingProgress: (fraction, index) =>
          phases.add('encode:$index:$fraction'),
      onVerificationProgress: (fraction, index) =>
          phases.add('verify:$index:$fraction'),
      onUploadProgress: (sent, total, index) =>
          phases.add('upload:$index:$sent/$total'),
    );

    expect(phases.first, 'encode:0:1.0');
    expect(phases[1], 'verify:0:1.0');
    expect(phases, contains('upload:0:3/3'));
  });

  test('failed video verification prevents upload and post creation', () async {
    final attachments = _FakeAttachmentRepository();
    final posts = _RecordingPostRepository();
    final publisher = PostAttachmentPublisher(
      postRepository: posts,
      attachmentRepository: attachments,
      videoEncoder: const _FailingVideoEncoder(),
    );

    await expectLater(
      publisher.publish(
        post: _postInput(),
        mediaFiles: [
          XFile.fromData(Uint8List.fromList([1]), mimeType: 'video/mp4')
        ],
      ),
      throwsA(isA<VideoUploadException>()),
    );
    expect(attachments.uploadedFilenames, isEmpty);
    expect(posts.createdInput, isNull);
  });

  test('video transfer failure is reported as an upload failure', () async {
    final attachments = _FakeAttachmentRepository(failOnUpload: 1);
    final publisher = PostAttachmentPublisher(
      postRepository: _RecordingPostRepository(),
      attachmentRepository: attachments,
      videoEncoder: _RecordingVideoEncoder(),
    );

    await expectLater(
      publisher.publish(
        post: _postInput(),
        mediaFiles: [
          XFile.fromData(Uint8List.fromList([1]), mimeType: 'video/mp4')
        ],
      ),
      throwsA(isA<VideoUploadException>()),
    );
  });

  test('uploads selected photos without a second encoding step', () async {
    final encoder = _RecordingVideoEncoder();
    final attachments = _FakeAttachmentRepository();
    final publisher = PostAttachmentPublisher(
      postRepository: _RecordingPostRepository(),
      attachmentRepository: attachments,
      videoEncoder: encoder,
    );
    var encodingCalls = 0;

    await publisher.publish(
      post: _postInput(),
      mediaFiles: [
        XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg')
      ],
      onEncodingProgress: (_, __) => encodingCalls++,
    );

    expect(encoder.calls, 0);
    expect(encodingCalls, 0);
    expect(attachments.uploadedFilenames, ['post-attachment-1']);
  });

  test('removes encoded video when publishing fails', () async {
    final directory = await Directory.systemTemp.createTemp('post-video-test-');
    addTearDown(() => directory.delete(recursive: true));
    final output = File('${directory.path}/encoded.mp4');
    await output.writeAsBytes([1, 2, 3]);
    final publisher = PostAttachmentPublisher(
      postRepository: _RecordingPostRepository(error: StateError('failed')),
      attachmentRepository: _FakeAttachmentRepository(),
      videoEncoder: _TemporaryVideoEncoder(output),
    );

    await expectLater(
      publisher.publish(
        post: _postInput(),
        mediaFiles: [
          XFile.fromData(Uint8List.fromList([4]), mimeType: 'video/mp4')
        ],
      ),
      throwsStateError,
    );
    expect(await output.exists(), isFalse);
  });
}

class _RecordingVideoEncoder implements VideoEncoder {
  int calls = 0;

  @override
  Future<EncodedVideo> encode(
    XFile source, {
    void Function(double fraction)? onProgress,
    void Function(double fraction)? onVerificationProgress,
  }) async {
    calls++;
    onProgress?.call(1);
    onVerificationProgress?.call(1);
    return EncodedVideo(source, isTemporary: false);
  }
}

class _FailingVideoEncoder implements VideoEncoder {
  const _FailingVideoEncoder();

  @override
  Future<EncodedVideo> encode(
    XFile source, {
    void Function(double fraction)? onProgress,
    void Function(double fraction)? onVerificationProgress,
  }) async {
    onVerificationProgress?.call(0.5);
    throw StateError('Video decode failed');
  }
}

class _TemporaryVideoEncoder implements VideoEncoder {
  const _TemporaryVideoEncoder(this.output);

  final File output;

  @override
  Future<EncodedVideo> encode(
    XFile source, {
    void Function(double fraction)? onProgress,
    void Function(double fraction)? onVerificationProgress,
  }) async =>
      EncodedVideo(XFile(output.path, mimeType: 'video/mp4'),
          isTemporary: true);
}

CreatePostInput _postInput() => CreatePostInput(
      language: 'en',
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
    required Stream<List<int>> content,
    required int byteLength,
    required String filename,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    final bytes = await content.expand((chunk) => chunk).toList();
    onProgress?.call(bytes.length, byteLength);
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
