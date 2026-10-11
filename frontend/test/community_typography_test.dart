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
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/fake_video_platform.dart';
import 'support/stub_community_repository.dart';

const _englishTitle = 'Title goes here';
const _koreanTitle =
    '[문도 데포르티보] UEFA는 스페인 법원에서 스포츠 부패가 입증돼야 바르사 징계 여부를 결정할 수 있음';
const _body =
    'First sentence goes here. Second sentence goes here. Third sentence goes here.';
const _url =
    'https://www.mundodeportivo.com/futbol/fc-barcelona/20261001/1004233430/uefa-confirma.html';

void main() {
  testWidgets('post content keeps its typography when the app language changes',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => appLocaleController.value = const Locale('en'));
    final originalVideo = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = originalVideo);
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf')))
        .load();
    final boundary = GlobalKey();
    final measurements = <String, Map<String, Size>>{};
    for (final language in ['en', 'ko']) {
      appLocaleController.value = Locale(language);
      await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                for (var i = 0; i < 2; i++) ...[
                  CommunityPostCard(
                    key: ValueKey('card-$i'),
                    post: Post(
                      postId: i + 1,
                      teamId: 83,
                      language: language,
                      userId: 8,
                      username: 'Username',
                      displayName: 'Username',
                      createdAt: '2026-10-08T00:00:00Z',
                      editedAt: i == 0 ? '2026-10-09T00:00:00Z' : null,
                      category: PostCategory.general,
                      title: i == 0 ? _englishTitle : _koreanTitle,
                      body: i == 0 ? _body : _url,
                      likeCount: 1290,
                      attachments: const [
                        PostAttachment(
                          attachmentId: 1,
                          position: 0,
                          contentType: 'video/mp4',
                          mediaUrl: 'https://example.com/video.mp4',
                        ),
                      ],
                    ),
                    onTap: () {},
                  ),
                  const CommunityPostSeparator(),
                ],
              ]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final sizes = <String, Size>{};
      for (var i = 0; i < 2; i++) {
        final card = find.byKey(ValueKey('card-$i'));
        final header = find.descendant(
            of: card, matching: find.byType(CommunityAuthorHeader));
        final title = find.text(i == 0 ? _englishTitle : _koreanTitle);
        final body = find.descendant(
            of: card, matching: find.byType(CommunityLinkedText));
        final name = find.descendant(of: card, matching: find.text('Username'));
        final like = find.descendant(
            of: card,
            matching: find.byWidgetPredicate(
                (widget) => widget is CommunityIcon && widget.name == 'like'));
        final titleParagraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: title, matching: find.byType(RichText)));
        expect(titleParagraph.didExceedMaxLines, i == 1);
        expect(tester.getSize(title).height, i == 0 ? 20 : 48);
        expect(tester.getSize(body).height, 40);
        expect(tester.getSize(name).height, 19);
        expect(tester.getSize(header).height, 37);
        expect(
            tester.getTopLeft(title).dy - tester.getBottomLeft(header).dy, 4);
        expect(tester.getTopLeft(body).dy - tester.getBottomLeft(title).dy, 4);
        expect(tester.getTopLeft(like).dy - tester.getBottomLeft(body).dy, 12);
        expect(tester.widget<Text>(title).style!.letterSpacing, 0);
        final media =
            find.byKey(ValueKey('community-post-${i + 1}-media-open'));
        expect(tester.getSize(media).width, 119);
        expect(tester.getSize(media).height, tester.getSize(card).height);
        sizes['name-$i'] = tester.getSize(name);
        sizes['title-$i'] = tester.getSize(title);
        sizes['body-$i'] = tester.getSize(body);
      }
      measurements[language] = sizes;
      expect(tester.takeException(), isNull);
      const output = String.fromEnvironment('COMMUNITY_CAPTURE_DIR');
      if (output.isNotEmpty) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/typography-$language.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    // 같은 글은 앱 언어를 바꿔도 같은 크기로 보여야 해요.
    expect(measurements['ko'], measurements['en']);
  });

  testWidgets('post and comment authors share the Figma line boxes',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => appLocaleController.value = const Locale('en'));
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf')))
        .load();
    for (final language in ['en', 'ko']) {
      appLocaleController.value = Locale(language);
      for (final scale in [1.0, 2.0]) {
        const post = Post(
          postId: 1,
          teamId: 83,
          language: 'en',
          userId: 8,
          category: PostCategory.general,
          displayName: 'Username',
          title: 'Title',
          body: 'Body',
          createdAt: '2026-10-08T00:00:00Z',
          editedAt: '2026-10-09T00:00:00Z',
        );
        await tester.pumpWidget(MaterialApp(
          theme: darktheme,
          locale: Locale(language),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CommunityPostCard(post: post, onTap: () {}),
                ),
              ),
              PostDetailContent(
                post: post,
                liked: false,
                likeCount: 0,
                commentCount: 2,
                onLike: null,
                communityRepository: const StubCommunityRepository(),
                comments: [
                  for (var id = 1; id <= 2; id++)
                    PostComment(
                      commentId: id,
                      postId: 1,
                      userId: 8,
                      replyToId: id == 2 ? 1 : null,
                      body: '댓글 본문',
                      createdAt: post.createdAt,
                      editedAt: id == 1 ? post.editedAt : null,
                      state: PostCommentState.active,
                      username: 'member',
                      displayName: id == 1 ? '그리즈만' : 'Username',
                      avatarUrl: null,
                      authorDeleted: false,
                      likeCount: 0,
                      liked: false,
                    ),
                ],
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
        final headers = find.byType(CommunityAuthorHeader);
        expect(headers, findsNWidgets(4));
        for (var i = 0; i < 4; i++) {
          final header = headers.at(i);
          final texts =
              find.descendant(of: header, matching: find.byType(Text));
          final avatar =
              find.descendant(of: header, matching: find.byType(CircleAvatar));
          // 기본 배율은 Figma와 같고, 글자 확대 때는 줄마다 생기는 반올림을 허용해요.
          final rounding = scale == 1 ? 0.0 : 1.0;
          expect(tester.getSize(texts.at(0)).height,
              closeTo(19 * scale, rounding));
          expect(tester.getSize(texts.at(1)).height,
              closeTo(18 * scale, rounding));
          expect(
              tester.getSize(header).height, closeTo(37 * scale, rounding * 2));
          expect(tester.getSize(avatar), const Size(32, 32));
          expect(tester.getCenter(avatar).dy, tester.getCenter(header).dy);
          expect(
              tester.getTopLeft(texts.at(0)).dx - tester.getTopRight(avatar).dx,
              8);
          expect(
              tester.getTopLeft(texts.at(1)).dy -
                  tester.getBottomLeft(texts.at(0)).dy,
              0);
          expect(
              tester.widget<Text>(texts.at(1)).data!.contains(' • '), i != 3);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
}
