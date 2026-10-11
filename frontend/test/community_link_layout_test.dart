import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/features/community/community_link_preview.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'support/fake_webview_platform.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';
import 'support/stub_community_repository.dart';

const _shortLink = 'https://www.instagram.com/p/DeM7w8vjIk6';
const _longLink =
    'https://www.mundodeportivo.com/futbol/fc-barcelona/20261001/1004233430/uefa-confirma-recibido-informe-madrid-sobre-caso-negreira.html';
const _paragraph = '어제는 제 마지막 경기였습니다. 벌써 하늘색과 흰색 유니폼을 입는 게 그립네요.';
const _paragraphBody = '$_shortLink\n\n$_paragraph';

void main() {
  for (final language in ['en', 'ko']) {
    testWidgets('$language link previews hug their text and keep the 12px gap',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appLocaleController.value = Locale(language);
      addTearDown(() => appLocaleController.value = const Locale('en'));
      await (FontLoader('Archivo')
            ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
          .load();
      await (FontLoader('Pretendard')
            ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
            ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf')))
          .load();
      final boundary = GlobalKey();
      var opens = 0;
      await tester.pumpWidget(MaterialApp(
          theme: whitetheme,
          locale: Locale(language),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                  body: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        for (var i = 0; i < 3; i++) ...[
                          CommunityPostCard(
                              key: ValueKey('card-$i'),
                              post: Post(
                                  postId: i + 1,
                                  teamId: 83,
                                  language: language,
                                  userId: 8,
                                  category: PostCategory.news,
                                  displayName: '리오넬 메시',
                                  createdAt: '2026-10-08T00:00:00Z',
                                  title: i != 1
                                      ? '[메시 인스타그램] 아르헨티나 대표팀 은퇴사'
                                      : '[문도 데포르티보] UEFA는 스페인 법원에서 스포츠 부패가 입증돼야',
                                  body: [
                                    _shortLink,
                                    _longLink,
                                    _paragraphBody
                                  ][i]),
                              onTap: () => opens++),
                          const CommunityPostSeparator(),
                        ],
                      ]))))));
      await tester.pumpAndSettle();
      final heights = <double>[];
      for (var i = 0; i < 3; i++) {
        final card = find.byKey(ValueKey('card-$i'));
        final linked = find.descendant(
            of: card, matching: find.byType(CommunityLinkedText));
        final icon = find.descendant(
            of: linked,
            matching: find.byWidgetPredicate(
                (widget) => widget is CommunityIcon && widget.name == 'link'));
        final like = find.descendant(
            of: card,
            matching: find.byWidgetPredicate(
                (widget) => widget is CommunityIcon && widget.name == 'like'));
        expect(tester.getSize(icon), const Size(16, 16));
        expect(tester.getTopLeft(like).dy - tester.getBottomLeft(linked).dy,
            closeTo(12, .001));
        heights.add(tester.getSize(linked).height);
        final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: linked, matching: find.byType(RichText)).first);
        final textStart = paragraph
            .getBoxesForSelection(
                const TextSelection(baseOffset: 1, extentOffset: 2))
            .first;
        expect(
            paragraph.localToGlobal(Offset(textStart.left, 0)).dx -
                tester.getTopRight(icon).dx,
            closeTo(4, .01));
        if (i == 1) {
          final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 1, extentOffset: _longLink.length + 1));
          expect(boxes.last.top, greaterThan(boxes.first.top));
          expect(boxes.last.left, closeTo(0, 1));
        }
        if (i == 2) {
          final text = paragraph.text.toPlainText();
          final start = text.indexOf(_paragraph);
          final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: start + 3));
          expect(boxes, isNotEmpty,
              reason: '빈 줄 대신 다음 문단이 두 번째 미리보기 줄에 보여야 해요.');
          expect(boxes.first.bottom, lessThanOrEqualTo(heights[i]));
        }
        await tester.tap(icon);
        expect(opens, i + 1);
      }
      expect(heights[1], closeTo(heights[0] * 2, 1));
      // URL 한 줄과 한글 한 줄은 각각의 행간을 써요. 앱 언어로 늘리지 않아요.
      expect(heights[0], 20);
      expect(heights[2], heights[0] + 24);
      expect(tester.takeException(), isNull);

      const output = String.fromEnvironment('COMMUNITY_CAPTURE_DIR');
      if (output.isNotEmpty) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/link-layout-$language.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets('post detail keeps text paragraphs after an inline link card',
      (tester) async {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    await tester.pumpWidget(MaterialApp(
        theme: whitetheme,
        home: Scaffold(
            body: CustomScrollView(slivers: [
          PostDetailContent(
              post: const Post(
                  postId: 16,
                  teamId: 83,
                  language: 'ko',
                  userId: 8,
                  category: PostCategory.news,
                  title: 'Title',
                  body: _paragraphBody,
                  createdAt: '2026-10-08T00:00:00Z'),
              liked: false,
              likeCount: 0,
              commentCount: 0,
              onLike: null,
              communityRepository: const StubCommunityRepository(),
              comments: const [],
              commentsLoading: false,
              commentsError: null,
              onRetryComments: () {},
              onReply: null,
              onReport: null),
        ]))));
    await tester.pump();
    platform.controllers.single.message('{"height":200}');
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(find
        .descendant(
            of: find.byType(CommunityLinkedText),
            matching: find.byType(RichText))
        .first);
    expect(paragraph.text.toPlainText(includePlaceholders: false), _paragraph);
    expect(find.byType(CommunityLinkPreview), findsOneWidget);
    expect(
        tester.getTopLeft(find.byType(CommunityLinkedText)).dy -
            tester.getBottomLeft(find.byType(CommunityLinkPreview)).dy,
        24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('link icon and URL open the same target in the detail text',
      (tester) async {
    final launches = <MethodCall>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      launches.add(call);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CommunityLinkedText(
                text: _shortLink,
                showLinkIcons: true,
                style: TextStyle(fontSize: 15)))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CommunityIcon));
    final paragraph = tester.renderObject<RenderParagraph>(find
        .descendant(
            of: find.byType(CommunityLinkedText),
            matching: find.byType(RichText))
        .first);
    final box = paragraph
        .getBoxesForSelection(
            const TextSelection(baseOffset: 1, extentOffset: 6))
        .first;
    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    expect(launches.map((call) => call.arguments['url']),
        [_shortLink, _shortLink]);
    expect(tester.takeException(), isNull);
  });
}
