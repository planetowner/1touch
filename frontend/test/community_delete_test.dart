import 'support/app_catalog.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/models/uploaded_post_attachment.dart';
import 'package:onetouch/screens/CommunityScreen_utils/add_post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/post_screen.dart';

import 'support/stub_community_repository.dart';
import 'support/stub_post_comment_repository.dart';

const _ownPost = Post(
  postId: 91,
  teamId: 83,
  userId: 1001,
  category: PostCategory.general,
  title: 'My post',
  body: 'My words',
  createdAt: '2026-09-29T10:00:00Z',
);

const _otherPost = Post(
  postId: 92,
  teamId: 83,
  userId: 2000,
  category: PostCategory.general,
  title: 'Other post',
  body: 'Other words',
  createdAt: '2026-09-29T10:00:00Z',
  commentCount: 1,
);

void main() {
  setUpAppCatalog(favoriteTeamId: 83);

  test('edited posts use the existing relative time labels', () {
    final now = DateTime.parse('2026-09-30T12:00:00Z');
    const createdAt = '2026-09-29T12:00:00Z';
    const editedAt = '2026-09-30T11:00:00Z';
    expect(
      communityPostTimeLabel(
        createdAt: createdAt,
        editedAt: editedAt,
        locale: const Locale('en'),
        now: now,
      ),
      'Updated 1h ago',
    );
    expect(
      communityPostTimeLabel(
        createdAt: createdAt,
        editedAt: editedAt,
        locale: const Locale('ko'),
        now: now,
      ),
      '1시간 전에 수정됨',
    );
    expect(
      communityPostTimeLabel(
        createdAt: createdAt,
        locale: const Locale('en'),
        now: now,
      ),
      '1d ago',
    );
  });

  testWidgets('only the author can confirm and delete a post', (tester) async {
    _usePhone(tester);
    final repository = MockPostRepository(posts: [_ownPost]);
    bool? deletionResult;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              deletionResult = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(
                    post: _ownPost,
                    currentUserId: 1001,
                    postRepository: repository,
                    communityRepository: const StubCommunityRepository(),
                    postCommentRepository: const StubPostCommentRepository(),
                  ),
                ),
              );
            },
            child: const Text('Open post'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open post'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('community-post-delete-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete post?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await repository.loadPosts(teamId: 83)).single.postId, 91);

    await tester.tap(find.byKey(const ValueKey('community-post-delete-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-confirm-delete')));
    await tester.pumpAndSettle();
    expect(deletionResult, isTrue);
    expect(await repository.loadPosts(teamId: 83), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('own active comment can be deleted without exposing other post',
      (tester) async {
    _usePhone(tester);
    final comments = _DeletingCommentsRepository();
    await tester.pumpWidget(MaterialApp(
      home: PostDetailScreen(
        post: _otherPost,
        currentUserId: 1001,
        postRepository: MockPostRepository(posts: [_otherPost]),
        communityRepository: const StubCommunityRepository(),
        postCommentRepository: comments,
      ),
    ));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('community-post-delete-menu')), findsNothing);
    expect(
        find.byKey(const ValueKey('community-comment-delete-2')), findsNothing);

    final ownMenu = find.byKey(const ValueKey('community-comment-delete-1'));
    await tester.scrollUntilVisible(
      ownMenu,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(ownMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete comment?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-confirm-delete')));
    await tester.pumpAndSettle();

    expect(comments.deletedIds, [1]);
    expect(find.text('This comment was deleted.'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('community-comment-delete-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('author can edit a post and see its new title and body',
      (tester) async {
    _usePhone(tester);
    final repository = MockPostRepository(posts: [_ownPost]);
    await tester.pumpWidget(MaterialApp(
      home: PostDetailScreen(
        post: _ownPost,
        currentUserId: 1001,
        postRepository: repository,
        communityRepository: const StubCommunityRepository(),
        postCommentRepository: const StubPostCommentRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('community-post-delete-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('community-post-title-input')),
      'Updated title',
    );
    await tester.enterText(
      find.byKey(const ValueKey('community-post-body-input')),
      'Updated body',
    );
    await tester.tap(find.byKey(const ValueKey('community-post-submit')));
    await tester.pumpAndSettle();

    final stored = (await repository.loadPosts(teamId: 83)).single;
    expect(stored.title, 'Updated title');
    expect(stored.body, 'Updated body');
    expect(find.text('Updated title'), findsOneWidget);
    expect(find.text('Updated body'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Updated (just now|\d+[mhd] ago)$')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('edited post media shows loading, error, and retry',
      (tester) async {
    _usePhone(tester);
    const post = Post(
      postId: 95,
      teamId: 83,
      userId: 1001,
      category: PostCategory.general,
      title: 'Original title',
      body: 'Original body',
      createdAt: '2026-09-29T10:00:00Z',
      attachments: [PostAttachment(attachmentId: 7, position: 0)],
    );
    final repository = _RefreshingPostRepository(posts: [post]);
    await tester.pumpWidget(MaterialApp(
      home: PostDetailScreen(
        post: post,
        currentUserId: 1001,
        postRepository: repository,
        communityRepository: const StubCommunityRepository(),
        postCommentRepository: const StubPostCommentRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('community-post-delete-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('community-post-title-input')),
      'Updated title',
    );
    await tester.tap(find.byKey(const ValueKey('community-post-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repository.loadRequests, hasLength(1));
    expect(find.byKey(const ValueKey('community-detail-media-loading')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('community-detail-media-open')),
        findsNothing);

    repository.loadRequests.first.completeError(StateError('Network error'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-detail-media-error')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('community-detail-media-retry')));
    await tester.pump();
    expect(repository.loadRequests, hasLength(2));
    expect(find.byKey(const ValueKey('community-detail-media-loading')),
        findsOneWidget);

    repository.loadRequests.last.complete([
      post.copyWith(
        title: 'Updated title',
        attachments: const [
          PostAttachment(
            attachmentId: 7,
            position: 0,
            mediaUrl: 'https://example.test/updated-image.jpg',
          ),
        ],
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-detail-media-open')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('community-detail-media-loading')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('author can edit their comment', (tester) async {
    _usePhone(tester);
    final comments = _DeletingCommentsRepository();
    await tester.pumpWidget(MaterialApp(
      home: PostDetailScreen(
        post: _otherPost,
        currentUserId: 1001,
        postRepository: MockPostRepository(posts: [_otherPost]),
        communityRepository: const StubCommunityRepository(),
        postCommentRepository: comments,
      ),
    ));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('community-comment-delete-1'));
    await tester.scrollUntilVisible(
      menu,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('community-comment-input')),
      'Updated comment',
    );
    await tester.tap(find.byKey(const ValueKey('community-comment-send')));
    await tester.pumpAndSettle();

    expect(comments.body, 'Updated comment');
    expect(find.text('Updated comment'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Updated (just now|\d+[mhd] ago)$')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing post composer can replace an attachment',
      (tester) async {
    _usePhone(tester);
    const post = Post(
      postId: 93,
      teamId: 83,
      userId: 1001,
      category: PostCategory.general,
      title: 'Original title',
      body: 'Original body',
      createdAt: '2026-09-29T10:00:00Z',
      attachments: [
        PostAttachment(
          attachmentId: 7,
          position: 0,
          linkUrl: 'https://example.com/old',
        ),
      ],
    );
    final posts = MockPostRepository(posts: [post]);
    final attachments = _EditingAttachmentsRepository();
    await tester.pumpWidget(MaterialApp(
      home: AddPost(
        editingPost: post,
        postRepository: posts,
        attachmentRepository: attachments,
        pickMedia: () async => [
          XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'new.jpg')
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Original title'), findsOneWidget);
    expect(find.text('Original body'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ANALYSIS').last);
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const ValueKey('community-existing-attachment-remove-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-media-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-post-submit')));
    await tester.pumpAndSettle();

    expect(attachments.uploadedNames, ['post-attachment']);
    final updated = (await posts.loadPosts(teamId: 83)).single;
    expect(updated.category, PostCategory.analysis);
    expect(updated.attachments.single.attachmentId, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old attachment preview is removed before the update request',
      (tester) async {
    _usePhone(tester);
    const post = Post(
      postId: 94,
      teamId: 83,
      userId: 1001,
      category: PostCategory.general,
      title: 'Original title',
      body: 'Original body',
      createdAt: '2026-09-29T10:00:00Z',
      attachments: [
        PostAttachment(
          attachmentId: 7,
          position: 0,
          linkUrl: 'https://example.com/old',
        ),
      ],
    );
    final repository = _WaitingPostRepository(posts: [post]);
    await tester.pumpWidget(MaterialApp(
      home: AddPost(editingPost: post, postRepository: repository),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-existing-attachment-remove-0')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('community-post-submit')));
    await tester.pump();
    expect(find.byKey(const ValueKey('community-existing-attachment-remove-0')),
        findsNothing);
    expect(repository.updateStarted, isTrue);
    repository.release.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _DeletingCommentsRepository implements PostCommentRepository {
  final deletedIds = <int>[];
  bool deleted = false;
  String body = 'My comment';
  String? editedAt;

  @override
  Future<int> createComment({
    required int postId,
    required String body,
    int? replyToId,
  }) async =>
      3;

  @override
  Future<void> deleteComment({required int commentId}) async {
    deletedIds.add(commentId);
    deleted = true;
  }

  @override
  Future<void> updateComment(
      {required int commentId, required String body}) async {
    this.body = body;
    editedAt = '2026-09-30T10:00:00Z';
  }

  @override
  Future<List<PostComment>> loadForPost({
    required int postId,
    int afterId = 0,
    int limit = 50,
  }) async =>
      [
        PostComment(
          commentId: 1,
          postId: postId,
          userId: deleted ? null : 1001,
          replyToId: null,
          body: deleted ? '' : body,
          createdAt: '2026-09-29T10:00:00Z',
          editedAt: editedAt,
          state: deleted ? PostCommentState.deleted : PostCommentState.active,
          username: deleted ? null : 'me',
          avatarUrl: null,
          authorDeleted: false,
          likeCount: 0,
          liked: false,
        ),
        PostComment(
          commentId: 2,
          postId: postId,
          userId: 2000,
          replyToId: null,
          body: 'Their comment',
          createdAt: '2026-09-29T10:00:00Z',
          editedAt: null,
          state: PostCommentState.active,
          username: 'them',
          avatarUrl: null,
          authorDeleted: false,
          likeCount: 0,
          liked: false,
        ),
      ];
}

class _EditingAttachmentsRepository implements PostAttachmentRepository {
  final uploadedNames = <String>[];

  @override
  Future<UploadedPostAttachment> upload(
      {required Uint8List bytes, required String filename}) async {
    uploadedNames.add(filename);
    return const UploadedPostAttachment(
        attachmentId: 8, contentType: 'image/jpeg', byteSize: 3);
  }

  @override
  Future<void> delete(int attachmentId) async {}
}

class _WaitingPostRepository extends MockPostRepository {
  _WaitingPostRepository({required super.posts});

  final release = Completer<void>();
  bool updateStarted = false;

  @override
  Future<void> updatePost(UpdatePostInput input) async {
    updateStarted = true;
    await release.future;
    await super.updatePost(input);
  }
}

class _RefreshingPostRepository extends MockPostRepository {
  _RefreshingPostRepository({required super.posts});

  final loadRequests = <Completer<List<Post>>>[];

  @override
  Future<List<Post>> loadPosts({
    required int teamId,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) {
    final request = Completer<List<Post>>();
    loadRequests.add(request);
    return request.future;
  }
}
