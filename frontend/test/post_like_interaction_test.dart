import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

import 'support/stub_community_repository.dart';
import 'support/stub_post_comment_repository.dart';

void main() {
  testWidgets('optimistically likes and unlikes without duplicate requests',
      (tester) async {
    _setScreenSize(tester);
    final firstRequest = Completer<void>();
    final repository = _LikePostRepository([
      (_) => firstRequest.future,
      (_) => Future.value(),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(
          post: _post,
          postRepository: repository,
          communityRepository: const StubCommunityRepository(),
          postCommentRepository: const StubPostCommentRepository(),
        ),
      ),
    );
    await _showLikeAction(tester);

    expect(_likeCount(tester), '1,290');
    expect(_likeIcon(tester), Icons.thumb_up_alt_outlined);

    await tester.tap(_likeAction);
    await tester.pump();
    expect(_likeCount(tester), '1,291');
    expect(_likeIcon(tester), Icons.thumb_up_alt);
    expect(repository.updates, [(postId: 91, liked: true)]);

    await tester.tap(_likeAction);
    await tester.pump();
    expect(repository.updates, hasLength(1));
    expect(_likeCount(tester), '1,291');

    firstRequest.complete();
    await tester.pumpAndSettle();
    await tester.tap(_likeAction);
    await tester.pumpAndSettle();

    expect(repository.updates, [
      (postId: 91, liked: true),
      (postId: 91, liked: false),
    ]);
    expect(_likeCount(tester), '1,290');
    expect(_likeIcon(tester), Icons.thumb_up_alt_outlined);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rolls back the optimistic update when the request fails',
      (tester) async {
    _setScreenSize(tester);
    final repository = _LikePostRepository([
      (_) => Future.error(StateError('Unavailable')),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(
          post: _post,
          postRepository: repository,
          communityRepository: const StubCommunityRepository(),
          postCommentRepository: const StubPostCommentRepository(),
        ),
      ),
    );
    await _showLikeAction(tester);

    await tester.tap(_likeAction);
    await tester.pumpAndSettle();

    expect(_likeCount(tester), '1,290');
    expect(_likeIcon(tester), Icons.thumb_up_alt_outlined);
    expect(
      find.text('Unable to update like. Please try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder get _likeAction =>
    find.byKey(const ValueKey('community-detail-like-action'));

String? _likeCount(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.byKey(const ValueKey('community-detail-like-count')),
      )
      .data;
}

IconData? _likeIcon(WidgetTester tester) {
  return tester
      .widget<Icon>(
        find.descendant(of: _likeAction, matching: find.byType(Icon)),
      )
      .icon;
}

Future<void> _showLikeAction(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    _likeAction,
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

class _LikePostRepository implements PostRepository {
  _LikePostRepository(this._responses);

  final List<Future<void> Function(bool liked)> _responses;
  final List<({int postId, bool liked})> updates = [];
  int _requestIndex = 0;

  @override
  Future<int> createPost(CreatePostInput input) {
    throw UnsupportedError('This test double only scripts likes.');
  }

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
    throw UnsupportedError('This test double only scripts likes.');
  }

  @override
  Future<void> reportPost({required int postId, required String reason}) {
    throw UnsupportedError('This test double only scripts likes.');
  }

  @override
  Future<void> setPostLiked({required int postId, required bool liked}) {
    updates.add((postId: postId, liked: liked));
    return _responses[_requestIndex++](liked);
  }
}

const _post = Post(
  postId: 91,
  teamId: 9,
  userId: 1001,
  category: PostCategory.general,
  title: 'Likeable post',
  body: 'Post body',
  createdAt: '2026-09-03 10:00:00',
  likeCount: 1290,
  commentCount: 12,
);
