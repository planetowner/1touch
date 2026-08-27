import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen.dart';

void main() {
  testWidgets('loads posts through the repository on a tall screen',
      (tester) async {
    _setScreenSize(tester, const Size(430, 932));
    final completer = Completer<List<Post>>();
    final repository = _ScriptedPostRepository([() => completer.future]);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Community(teamId: 9, postRepository: repository),
      ),
    );

    expect(
      find.byKey(const ValueKey('community-posts-loading')),
      findsOneWidget,
    );

    completer.complete(const [_loadedPost]);
    await tester.pumpAndSettle();

    expect(find.text(_loadedPost.title), findsOneWidget);
    expect(repository.calls, 1);
    expect(repository.lastCategory, isNull);
    expect(repository.lastSort, PostSort.newest);
    expect(repository.lastLimit, 50);
    expect(repository.lastOffset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error and retries on a compact screen', (tester) async {
    _setScreenSize(tester, const Size(320, 568));
    final repository = _ScriptedPostRepository([
      () => Future.error(StateError('Unavailable')),
      () => Future.value(const [_loadedPost]),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Community(teamId: 9, postRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load community posts.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('community-posts-retry')),
    );
    await tester.pumpAndSettle();

    expect(find.text(_loadedPost.title), findsOneWidget);
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a stale result after the repository changes',
      (tester) async {
    _setScreenSize(tester, const Size(393, 852));
    final firstResult = Completer<List<Post>>();
    final secondResult = Completer<List<Post>>();
    final firstRepository = _ScriptedPostRepository([() => firstResult.future]);
    final secondRepository =
        _ScriptedPostRepository([() => secondResult.future]);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Community(teamId: 9, postRepository: firstRepository),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Community(teamId: 9, postRepository: secondRepository),
      ),
    );

    secondResult.complete(const [_loadedPost]);
    await tester.pumpAndSettle();
    firstResult.complete(const [_stalePost]);
    await tester.pumpAndSettle();

    expect(find.text(_loadedPost.title), findsOneWidget);
    expect(find.text(_stalePost.title), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _ScriptedPostRepository implements PostRepository {
  _ScriptedPostRepository(this._responses);

  final List<Future<List<Post>> Function()> _responses;
  int calls = 0;
  PostCategory? lastCategory;
  PostSort? lastSort;
  int? lastLimit;
  int? lastOffset;

  @override
  Future<List<Post>> loadPosts({
    PostCategory? category,
    PostSort sort = PostSort.newest,
    int limit = 50,
    int offset = 0,
  }) {
    lastCategory = category;
    lastSort = sort;
    lastLimit = limit;
    lastOffset = offset;
    return _responses[calls++]();
  }
}

const _loadedPost = Post(
  postId: 91,
  userId: 1001,
  category: PostCategory.general,
  title: 'Repository post',
  body: 'Loaded through the repository.',
  createdAt: '2026-08-27 10:00:00',
);

const _stalePost = Post(
  postId: 90,
  userId: 1002,
  category: PostCategory.news,
  title: 'Stale repository post',
  body: 'This result should be ignored.',
  createdAt: '2026-08-26 10:00:00',
);
