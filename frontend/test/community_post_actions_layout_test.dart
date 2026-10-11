import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';

import 'support/stub_community_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf')))
        .load();
  });
  tearDown(() => appLocaleController.value = const Locale('en'));

  for (final (locale, share, report) in [
    (const Locale('en'), 'Share', 'Report'),
    (const Locale('ko'), '공유', '신고'),
    (const Locale('ja'), '共有', '報告'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      '分享',
      '举报'
    ),
  ]) {
    testWidgets(
        '${locale.languageCode} actions match the longest translated item',
        (tester) async {
      await _show(tester, locale: locale);
      expect(find.descendant(of: _action('share'), matching: find.text(share)),
          findsOneWidget);
      expect(
          find.descendant(of: _action('report'), matching: find.text(report)),
          findsOneWidget);
      _expectLayout(tester);
      if (locale.languageCode == 'en') {
        expect(_naturalWidth(tester, 'report'),
            greaterThan(_naturalWidth(tester, 'share')));
      }
    });
  }

  testWidgets('changing language recalculates the common width',
      (tester) async {
    await _show(tester);
    final englishWidth = _expectLayout(tester);
    await _show(tester, locale: const Locale('ko'));
    final koreanWidth = _expectLayout(tester);
    expect(koreanWidth, lessThan(englishWidth));
  });

  testWidgets('like and comment count updates can each become the widest item',
      (tester) async {
    await _show(tester, width: 440);
    final reportWidth = _expectLayout(tester);
    await _show(tester, width: 440, likes: 123456);
    final likeWidth = _expectLayout(tester);
    expect(find.text('123,456'), findsOneWidget);
    expect(likeWidth, greaterThan(reportWidth));
    expect(likeWidth, closeTo(_naturalWidth(tester, 'like'), .01));

    await _show(tester, width: 440, likes: 123456, comments: 9876543);
    final commentWidth = _expectLayout(tester);
    expect(find.text('9,876,543'), findsOneWidget);
    expect(commentWidth, greaterThan(likeWidth));
    expect(commentWidth, closeTo(_naturalWidth(tester, 'comment'), .01));

    await _show(tester, width: 440);
    expect(_expectLayout(tester), closeTo(reportWidth, .01));
  });

  testWidgets('text scaling and bold text are included in the common width',
      (tester) async {
    await _show(tester, width: 600);
    final initialWidth = _expectLayout(tester);
    await _show(tester, width: 600, textScale: 1.5);
    final scaledWidth = _expectLayout(tester);
    expect(scaledWidth, greaterThan(initialWidth));
    await _show(tester, width: 600, textScale: 1.5, boldText: true);
    _expectLayout(tester);
  });

  testWidgets('narrow screens keep equal widths and both outer edges',
      (tester) async {
    await _show(tester, width: 320, likes: 1234567890);
    _expectLayout(tester, constrained: true);
    expect(_paragraph(tester, 'like').didExceedMaxLines, isTrue);
  });
}

Finder _action(String name) =>
    find.byKey(ValueKey('community-detail-$name-action'));

RenderParagraph _paragraph(WidgetTester tester, String name) =>
    tester.renderObject<RenderParagraph>(
        find.descendant(of: _action(name), matching: find.byType(RichText)));

double _naturalWidth(WidgetTester tester, String name) {
  final icon =
      find.descendant(of: _action(name), matching: find.byType(CommunityIcon));
  return tester.getSize(icon).width +
      4 +
      _paragraph(tester, name).getMaxIntrinsicWidth(double.infinity);
}

double _expectLayout(WidgetTester tester, {bool constrained = false}) {
  const names = ['like', 'comment', 'share', 'report'];
  final row =
      tester.getRect(find.byKey(const ValueKey('community-detail-actions')));
  final rects = [for (final name in names) tester.getRect(_action(name))];
  final longest =
      names.map((name) => _naturalWidth(tester, name)).reduce(math.max);
  final expectedWidth = constrained ? row.width / names.length : longest;
  if (constrained) expect(longest * names.length, greaterThan(row.width));
  for (var i = 0; i < names.length; i++) {
    expect(rects[i].width, closeTo(expectedWidth, .01));
    final icon = find.descendant(
        of: _action(names[i]), matching: find.byType(CommunityIcon));
    final label =
        find.descendant(of: _action(names[i]), matching: find.byType(RichText));
    expect(tester.getSize(icon), const Size(24, 24));
    expect(tester.getTopLeft(icon).dx, closeTo(rects[i].left, .01));
    expect(tester.getTopLeft(label).dx - tester.getTopRight(icon).dx,
        closeTo(4, .01));
    if (!constrained) {
      expect(_paragraph(tester, names[i]).didExceedMaxLines, false);
    }
  }
  expect(rects.first.left, row.left);
  expect(rects.last.right, closeTo(row.right, .01));
  final expectedGap = (row.width - expectedWidth * names.length) / 3;
  for (var i = 1; i < names.length; i++) {
    expect(rects[i].left - rects[i - 1].right, closeTo(expectedGap, .01));
  }
  expect(tester.takeException(), isNull);
  return rects.first.width;
}

Future<void> _show(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double width = 393,
  int likes = 88,
  int comments = 88,
  double textScale = 1,
  bool boldText = false,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  appLocaleController.value = locale;
  await tester.pumpWidget(MaterialApp(
    theme: darktheme,
    locale: locale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale), boldText: boldText),
      child: child!,
    ),
    home: Scaffold(
      body: CustomScrollView(slivers: [
        PostDetailContent(
          post: const Post(
            postId: 1,
            teamId: 83,
            language: 'en',
            userId: 1,
            category: PostCategory.general,
            title: 'Title',
            body: 'Body',
            createdAt: '2026-10-11T00:00:00Z',
          ),
          liked: false,
          likeCount: likes,
          commentCount: comments,
          onLike: null,
          communityRepository: const StubCommunityRepository(),
          comments: const [],
          commentsLoading: false,
          commentsError: null,
          onRetryComments: () {},
          onReply: null,
          onReport: null,
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}
