import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/community/mock/community_catalog.dart';
import 'package:onetouch/data/post_comments/post_comment_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/features/community/community_engagement.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

import 'support/stub_community_repository.dart';

void main() {
  testWidgets('loads and renders real comments and reply indentation',
      (tester) async {
    _setScreenSize(tester);
    final result = Completer<List<PostComment>>();
    final repository = _ScriptedPostCommentRepository([
      () => result.future,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(
          post: mockPosts.first,
          postRepository: MockPostRepository(),
          communityRepository: const StubCommunityRepository(),
          postCommentRepository: repository,
        ),
      ),
    );
    await _showComments(tester);

    expect(
      find.byKey(const ValueKey('community-comments-loading')),
      findsOneWidget,
    );

    result.complete([
      _comment(commentId: 11, body: 'Top-level comment'),
      _comment(
        commentId: 12,
        replyToId: 11,
        body: 'A real reply',
      ),
      _comment(
        commentId: 13,
        body: '',
        state: PostCommentState.deleted,
        userId: null,
        username: null,
      ),
    ]);
    await tester.pumpAndSettle();
    await _showComments(tester);

    expect(repository.requestedPostIds, [mockPosts.first.postId]);
    expect(find.text('Top-level comment'), findsOneWidget);
    expect(find.text('A real reply'), findsOneWidget);
    expect(find.text('This comment was deleted.'), findsOneWidget);
    expect(find.text('First sentence goes here.'), findsNothing);
    expect(
      find.byKey(const ValueKey('community-comment-reply-13')),
      findsNothing,
    );

    final topLevelX = tester
        .getTopLeft(find.byKey(const ValueKey('community-comment-11')))
        .dx;
    final replyX = tester
        .getTopLeft(find.byKey(const ValueKey('community-comment-12')))
        .dx;
    expect(replyX - topLevelX, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error and retries comment loading', (tester) async {
    _setScreenSize(tester);
    final repository = _ScriptedPostCommentRepository([
      () => Future.error(StateError('Unavailable')),
      () => Future.value([_comment(commentId: 21, body: 'Loaded on retry')]),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(
          post: mockPosts.first,
          postRepository: MockPostRepository(),
          communityRepository: const StubCommunityRepository(),
          postCommentRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _showComments(tester);

    expect(find.text('Unable to load comments.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-comments-retry')));
    await tester.pumpAndSettle();
    await _showComments(tester);

    expect(find.text('Loaded on retry'), findsOneWidget);
    expect(repository.requestedPostIds, [
      mockPosts.first.postId,
      mockPosts.first.postId,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a top-level comment and refreshes the detail',
      (tester) async {
    _setScreenSize(tester);
    final creation = Completer<int>();
    final createdComment = _comment(
      commentId: 31,
      body: 'Created from Flutter',
    );
    final repository = _ScriptedPostCommentRepository(
      [
        () => Future.value(const <PostComment>[]),
        () => Future.value([createdComment]),
      ],
      onCreate: (_, __, ___) => creation.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(
          post: mockPosts.first,
          postRepository: MockPostRepository(),
          communityRepository: const StubCommunityRepository(),
          postCommentRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('community-comment-input'));
    final send = find.byKey(const ValueKey('community-comment-send'));
    await tester.enterText(input, '  Created from Flutter  ');
    await tester.pump();
    await tester.tap(send);
    await tester.pump();

    expect(repository.createdComments, [
      (
        postId: mockPosts.first.postId,
        body: 'Created from Flutter',
        replyToId: null,
      ),
    ]);
    expect(
      find.byKey(const ValueKey('community-comment-submitting')),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(input).controller?.text,
        '  Created from Flutter  ');

    creation.complete(31);
    await tester.pumpAndSettle();
    await _showComment(tester, 31);

    expect(find.text('Created from Flutter'), findsOneWidget);
    expect(tester.widget<TextField>(input).controller?.text, isEmpty);
    expect(repository.requestedPostIds, [
      mockPosts.first.postId,
      mockPosts.first.postId,
    ]);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('community-detail-comment-count')),
          )
          .data,
      formatCommunityEngagementCount(mockPosts.first.commentCount + 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps comment text when creation fails', (tester) async {
    _setScreenSize(tester);
    final repository = _ScriptedPostCommentRepository(
      [() => Future.value(const <PostComment>[])],
      onCreate: (_, __, ___) => Future.error(StateError('Unavailable')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(
          post: mockPosts.first,
          postRepository: MockPostRepository(),
          communityRepository: const StubCommunityRepository(),
          postCommentRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('community-comment-input'));
    await tester.enterText(input, 'Keep this comment');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('community-comment-send')));
    await tester.pumpAndSettle();

    expect(
        tester.widget<TextField>(input).controller?.text, 'Keep this comment');
    expect(
      find.text('Unable to post comment. Please try again.'),
      findsOneWidget,
    );
    expect(repository.requestedPostIds, [mockPosts.first.postId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects a comment and submits its ID as the reply target',
      (tester) async {
    _setScreenSize(tester);
    final parent = _comment(commentId: 41, body: 'Parent comment');
    final reply = _comment(
      commentId: 42,
      replyToId: 41,
      body: 'Reply from Flutter',
    );
    final repository = _ScriptedPostCommentRepository(
      [
        () => Future.value([parent]),
        () => Future.value([parent, reply]),
      ],
      onCreate: (_, __, ___) => Future.value(42),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(
          post: mockPosts.first,
          postRepository: MockPostRepository(),
          communityRepository: const StubCommunityRepository(),
          postCommentRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _showComment(tester, 41);

    await tester.tap(
      find.byKey(const ValueKey('community-comment-reply-41')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('community-reply-target')),
      findsOneWidget,
    );
    expect(find.text('Replying to @planetowner'), findsOneWidget);

    final input = find.byKey(const ValueKey('community-comment-input'));
    await tester.enterText(input, 'Reply from Flutter');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('community-reply-cancel')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('community-reply-target')),
      findsNothing,
    );
    expect(
      tester.widget<TextField>(input).controller?.text,
      'Reply from Flutter',
    );

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _showComment(tester, 41);
    await tester.tap(
      find.byKey(const ValueKey('community-comment-reply-41')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('community-comment-send')));
    await tester.pumpAndSettle();
    await _showComment(tester, 42);

    expect(repository.createdComments, [
      (
        postId: mockPosts.first.postId,
        body: 'Reply from Flutter',
        replyToId: 41,
      ),
    ]);
    expect(find.text('Reply from Flutter'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('community-reply-target')),
      findsNothing,
    );
    expect(tester.widget<TextField>(input).controller?.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

class _ScriptedPostCommentRepository implements PostCommentRepository {
  _ScriptedPostCommentRepository(
    this._responses, {
    Future<int> Function(int postId, String body, int? replyToId)? onCreate,
  }) : _onCreate = onCreate;

  final List<Future<List<PostComment>> Function()> _responses;
  final Future<int> Function(int postId, String body, int? replyToId)?
      _onCreate;
  final List<int> requestedPostIds = [];
  final List<({int postId, String body, int? replyToId})> createdComments = [];
  int _requestIndex = 0;

  @override
  Future<int> createComment({
    required int postId,
    required String body,
    int? replyToId,
  }) {
    createdComments.add(
      (postId: postId, body: body, replyToId: replyToId),
    );
    final onCreate = _onCreate;
    if (onCreate == null) {
      throw UnsupportedError('This test double only scripts comment loading.');
    }
    return onCreate(postId, body, replyToId);
  }

  @override
  Future<List<PostComment>> loadForPost({
    required int postId,
    int afterId = 0,
    int limit = 50,
  }) {
    requestedPostIds.add(postId);
    return _responses[_requestIndex++]();
  }
}

PostComment _comment({
  required int commentId,
  required String body,
  int? replyToId,
  int? userId = 1001,
  String? username = 'planetowner',
  PostCommentState state = PostCommentState.active,
}) {
  return PostComment(
    commentId: commentId,
    postId: mockPosts.first.postId,
    userId: userId,
    replyToId: replyToId,
    body: body,
    createdAt: '2026-09-15T12:00:00Z',
    editedAt: null,
    state: state,
    username: username,
    avatarUrl: null,
    authorDeleted: userId == null,
    likeCount: 0,
    liked: false,
  );
}

Future<void> _showComments(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('community-comments-loading'));
  final fallback = find.byKey(const ValueKey('community-comments-error'));
  final content = find.byKey(const ValueKey('community-comment-11'));
  final retryContent = find.byKey(const ValueKey('community-comment-21'));
  final target = finder.evaluate().isNotEmpty
      ? finder
      : fallback.evaluate().isNotEmpty
          ? fallback
          : content.evaluate().isNotEmpty
              ? content
              : retryContent;
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _showComment(WidgetTester tester, int commentId) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey('community-comment-$commentId')),
    150,
    scrollable: find.byType(Scrollable).first,
  );
}

void _setScreenSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
