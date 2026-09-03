import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';

void main() {
  testWidgets('submits the selected report reason on a tall screen',
      (tester) async {
    _setScreenSize(tester, const Size(430, 932));
    final reportResult = Completer<void>();
    final repository = _ReportPostRepository(
      onReport: (_, __) => reportResult.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: PostDetailScreen(
          post: _post,
          postRepository: repository,
        ),
      ),
    );
    await _openReportDialog(tester);

    await tester.tap(find.byKey(const ValueKey('community-report-submit')));
    await tester.pump();
    expect(repository.reportCalls, 0);

    await tester.tap(find.text('Harassment & Bullying'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('community-report-submit')));
    await tester.pump();

    expect(repository.reportCalls, 1);
    expect(repository.reportedPostId, _post.postId);
    expect(repository.reportedReason, 'Harassment & Bullying');
    expect(
      find.byKey(const ValueKey('community-report-submitting')),
      findsOneWidget,
    );

    reportResult.complete();
    await tester.pumpAndSettle();

    expect(find.text('Thanks for your report!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a failed report open on a compact screen', (tester) async {
    _setScreenSize(tester, const Size(320, 568));
    final repository = _ReportPostRepository(
      onReport: (_, __) => Future.error(StateError('Unavailable')),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: PostDetailScreen(
          post: _post,
          postRepository: repository,
        ),
      ),
    );
    await _openReportDialog(tester);

    await tester.tap(find.text('Spam'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('community-report-submit')));
    await tester.pumpAndSettle();

    expect(repository.reportCalls, 1);
    expect(repository.reportedPostId, _post.postId);
    expect(repository.reportedReason, 'Spam');
    expect(
      find.text('Unable to submit report. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Thanks for your report!'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openReportDialog(WidgetTester tester) async {
  final reportAction = find.text('report');
  await tester.scrollUntilVisible(
    reportAction,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(reportAction);
  await tester.pumpAndSettle();
}

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _ReportPostRepository implements PostRepository {
  _ReportPostRepository({required this.onReport});

  final Future<void> Function(int postId, String reason) onReport;
  int reportCalls = 0;
  int? reportedPostId;
  String? reportedReason;

  @override
  Future<int> createPost(CreatePostInput input) {
    throw UnsupportedError('This test double only scripts reports.');
  }

  @override
  Future<List<Post>> loadPosts({
    PostCategory? category,
    PostSort sort = PostSort.newest,
    int limit = 50,
    int offset = 0,
  }) {
    throw UnsupportedError('This test double only scripts reports.');
  }

  @override
  Future<void> reportPost({required int postId, required String reason}) {
    reportCalls++;
    reportedPostId = postId;
    reportedReason = reason;
    return onReport(postId, reason);
  }
}

const _post = Post(
  postId: 91,
  userId: 1001,
  category: PostCategory.general,
  title: 'Reportable post',
  body: 'Post body',
  createdAt: '2026-09-03 10:00:00',
);
