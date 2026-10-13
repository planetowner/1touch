import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/link_previews/link_preview_repository.dart';
import 'package:onetouch/features/community/community_link_preview.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/community_post_rich_body.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/features/community/community_social_embed_cache.dart';
import 'package:onetouch/features/community/community_linked_text.dart';
import 'package:onetouch/features/community/post_detail_content.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/post.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'support/fake_webview_platform.dart';
import 'support/stub_community_repository.dart';

const _title =
    "'노이어가 이런 실수를 한다고?' 경기 시작 단 '8.4초' 만에 역대급 대형 사고!...분데스리가 최단 시간 실점 '불명예 신기록'→콤파니 감독은 감쌌다";

void main() {
  setUp(communitySocialEmbedCache.clear);
  tearDown(communitySocialEmbedCache.clear);
  Future<void> fonts() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf')))
        .load();
  }

  Widget app(Widget child, {ThemeData? theme}) => MaterialApp(
        theme: theme ?? darktheme,
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
            body: SingleChildScrollView(
                child:
                    Padding(padding: const EdgeInsets.all(24), child: child))),
      );

  testWidgets(
      'feed prepares the social view and detail uses its height on the first frame and on reopening',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    const post = Post(
        postId: 1,
        teamId: 83,
        language: 'ko',
        userId: 1,
        category: PostCategory.general,
        title: 'Post',
        createdAt: '',
        body:
            'https://www.instagram.com/p/Ready123/\n\nBody below the preview');
    await tester.pumpWidget(app(CommunityPostCard(post: post, onTap: () {})));
    await tester.pump();
    final controller = platform.controllers.single;
    expect(controller.html, contains('const width = 752.0;'));
    expect(find.byType(WebViewWidget), findsNothing);
    controller.message('{"height":300}');
    for (var opening = 0; opening < 2; opening++) {
      await tester.pumpWidget(
          app(CommunityPostRichBody(parts: communityPostParts(post))));
      expect(find.byType(FootballLoadingIndicator), findsNothing);
      expect(tester.getSize(find.byType(WebViewWidget)).height, 300);
      expect(
          tester.getTopLeft(find.byType(CommunityLinkedText)).dy -
              tester.getBottomLeft(find.byType(WebViewWidget)).dy,
          24);
      final firstPosition = tester.getTopLeft(find.byType(CommunityLinkedText));
      await tester.pumpAndSettle();
      expect(
          tester.getTopLeft(find.byType(CommunityLinkedText)), firstPosition);
      expect(platform.controllers, [controller]);
      await tester.pumpWidget(app(const SizedBox()));
    }
  });

  testWidgets(
      'an uncached website reveals following text in place, and a cached website has no loading frame',
      (tester) async {
    final response = Completer<http.Response>();
    var requests = 0;
    final repository = LinkPreviewRepository(client: MockClient((_) {
      requests++;
      return response.future;
    }));
    final parts = [
      (text: '', uri: Uri.parse('https://example.com/first')),
      (text: 'Body below article', uri: null)
    ];
    await tester.pumpWidget(
        app(CommunityPostRichBody(parts: parts, repository: repository)));
    await tester.pump();
    expect(find.byType(CommunityLinkedText), findsNothing);
    response.complete(http.Response('<title>Article</title>', 200,
        headers: {'content-type': 'text/html'}));
    await tester.pumpAndSettle();
    final firstPosition = tester.getTopLeft(find.byType(CommunityLinkedText));
    expect(
        firstPosition.dy -
            tester.getBottomLeft(find.byType(CommunityWebsiteCard)).dy,
        24);
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(
        app(CommunityPostRichBody(parts: parts, repository: repository)));
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(tester.getTopLeft(find.byType(CommunityLinkedText)), firstPosition);
    expect(requests, 1);
  });

  testWidgets(
      'an uncached social link keeps following text hidden until its measured height arrives',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    await tester.pumpWidget(app(CommunityPostRichBody(parts: [
      (text: '', uri: Uri.parse('https://x.com/a/status/456')),
      (text: 'Body below the post', uri: null),
    ])));
    await tester.pump();
    expect(find.byType(CommunityLinkedText), findsNothing);
    platform.controllers.single.message('{"height":250}');
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.byType(CommunityLinkedText)).dy -
            tester.getBottomLeft(find.byType(WebViewWidget)).dy,
        24);
  });

  testWidgets(
      'the same social link in two positions uses separate native views',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    final uri = Uri.parse('https://x.com/a/status/789');
    await tester.pumpWidget(app(Column(children: [
      CommunityLinkPreview(uri: uri),
      CommunityLinkPreview(uri: uri),
    ])));
    await tester.pump();
    expect(platform.controllers.length, 2);
    for (final controller in platform.controllers) {
      controller.message('{"height":100}');
    }
    await tester.pumpAndSettle();
    final views =
        tester.widgetList<WebViewWidget>(find.byType(WebViewWidget)).toList();
    expect(views[0].platform.params.controller,
        isNot(same(views[1].platform.params.controller)));
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpWidget(app(CommunityLinkPreview(uri: uri)));
    await tester.pumpAndSettle();
    expect(platform.controllers.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'website card matches Figma dimensions and opens its original URL',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await fonts();
    final launches = <MethodCall>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      launches.add(call);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final uri = Uri.parse(
        'https://www.mundodeportivo.com/futbol/fc-barcelona/20261001/article.html');
    final boundary = GlobalKey();
    for (final theme in [darktheme, whitetheme]) {
      await tester.pumpWidget(app(
          RepaintBoundary(
              key: boundary,
              child: CommunityWebsiteCard(
                  uri: uri,
                  data: LinkPreviewData(
                      title: _title,
                      imageUri: Uri.parse('https://example.com/photo.jpg')))),
          theme: theme));
      await tester.pumpAndSettle();
      final card = find.byType(CommunityWebsiteCard);
      final image =
          find.descendant(of: card, matching: find.byType(AspectRatio));
      final title = find.text(_title);
      final url = find.text(uri.toString());
      expect(tester.getSize(card).width, 345);
      expect(tester.getSize(image), const Size(345, 173));
      expect(tester.getTopLeft(title).dx - tester.getTopLeft(card).dx, 16);
      expect(tester.getTopLeft(title).dy - tester.getBottomLeft(image).dy, 16);
      expect(tester.getTopLeft(url).dy - tester.getBottomLeft(title).dy, 8);
      expect(tester.getBottomLeft(card).dy - tester.getBottomLeft(url).dy, 16);
      expect(tester.getSize(card).height, 307);
      final clip = tester.widget<ClipRRect>(
          find.descendant(of: card, matching: find.byType(ClipRRect)).first);
      expect(clip.borderRadius, BorderRadius.circular(8));
      final background = tester.widget<ColoredBox>(
          find.descendant(of: card, matching: find.byType(ColoredBox)).first);
      expect(
          background.color,
          theme.brightness == Brightness.dark
              ? AppPalette.darkGrey
              : AppPalette.white);
      expect(tester.widget<Text>(url).style!.fontSize, 12);
      await tester.tap(title);
      expect(launches.last.arguments['url'], uri.toString());
      expect(tester.takeException(), isNull);
      const output = String.fromEnvironment('COMMUNITY_CAPTURE_DIR');
      if (output.isNotEmpty) {
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/link-card-${theme.brightness.name}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });

  testWidgets(
      'social embeds follow reported heights, survive parent rebuilds and open external navigation',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      launches.add(call);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    for (final target in [
      'https://x.com/a/status/123',
      'https://www.instagram.com/p/Ab123/'
    ]) {
      final uri = Uri.parse(target);
      await tester.pumpWidget(app(CommunityLinkPreview(uri: uri)));
      await tester.pump();
      final controller = platform.controllers.last;
      expect(
          controller.html,
          contains(target.contains('instagram')
              ? 'instagram.com/embed.js'
              : 'platform.x.com/widgets.js'));
      controller.message('{"height":654}');
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(WebViewWidget)).height, 654);
      controller.message('{"height":980}');
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(WebViewWidget)).height, 980);
      final count = platform.controllers.length;
      await tester.pumpWidget(app(CommunityLinkPreview(uri: uri)));
      await tester.pump();
      expect(platform.controllers.length, count);
      expect(
          await controller.delegate.navigate(NavigationRequest(
              url: 'https://example.com/open', isMainFrame: true)),
          NavigationDecision.prevent);
      expect(launches.last.arguments['url'], 'https://example.com/open');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 25));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'X embeds follow the app theme on first load and while the post stays open',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    final uri = Uri.parse('https://x.com/a/status/123');
    final loaded = <Brightness, FakeWebViewController>{};
    for (final initialTheme in [whitetheme, darktheme]) {
      await tester.pumpWidget(const SizedBox());
      for (final theme in [
        initialTheme,
        initialTheme.brightness == Brightness.light ? darktheme : whitetheme,
        initialTheme,
      ]) {
        await tester
            .pumpWidget(app(CommunityLinkPreview(uri: uri), theme: theme));
        await tester.pump(kThemeAnimationDuration);
        final controller = tester
            .widget<WebViewWidget>(find.byType(WebViewWidget))
            .platform
            .params
            .controller as FakeWebViewController;
        if (loaded.containsKey(theme.brightness)) {
          expect(controller, same(loaded[theme.brightness]));
        } else {
          loaded[theme.brightness] = controller;
        }
        expect(platform.controllers.length, loaded.length);
        expect(controller.html, contains("theme: '${theme.brightness.name}'"));
        controller.message('{"height":654}');
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(WebViewWidget)).height, 654);

        await tester
            .pumpWidget(app(CommunityLinkPreview(uri: uri), theme: theme));
        await tester.pump();
        expect(platform.controllers.length, loaded.length);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Instagram stays loaded when only the app theme changes',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    final uri = Uri.parse('https://www.instagram.com/p/Ab123/');
    await tester
        .pumpWidget(app(CommunityLinkPreview(uri: uri), theme: whitetheme));
    await tester.pump();
    final controller = platform.controllers.single;
    controller.message('{"height":700}');
    await tester.pumpAndSettle();
    await tester
        .pumpWidget(app(CommunityLinkPreview(uri: uri), theme: darktheme));
    await tester.pumpAndSettle();
    expect(platform.controllers, [controller]);
    expect(tester.getSize(find.byType(WebViewWidget)).height, 700);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'social timeout keeps the original link and retry can load the embed',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    await tester.pumpWidget(app(
        CommunityLinkPreview(uri: Uri.parse('https://x.com/a/status/123'))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityLinkedText), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(platform.controllers.length, 2);
    platform.controllers.last.message('{"height":400}');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(WebViewWidget)).height, 400);
    expect(find.byType(TextButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable metadata leaves a usable URL and allows retry',
      (tester) async {
    var requests = 0;
    final repository = LinkPreviewRepository(
        client: MockClient((_) async => ++requests == 1
            ? http.Response('no', 403)
            : http.Response('<title>Recovered</title>', 200,
                headers: {'content-type': 'text/html'})));
    await tester.pumpWidget(app(CommunityLinkPreview(
        uri: Uri.parse('https://example.com'), repository: repository)));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityLinkedText), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
    expect(requests, 2);
  });

  testWidgets(
      'detail uses 24px before cards and 48/24px after website/social cards',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    final repository = LinkPreviewRepository(
        client: MockClient((_) async => http.Response(
            '<title>Article</title>', 200,
            headers: {'content-type': 'text/html'})));
    for (final url in ['https://example.com', 'https://x.com/a/status/123']) {
      await tester.pumpWidget(MaterialApp(
          theme: darktheme,
          home: Scaffold(
              body: CustomScrollView(slivers: [
            PostDetailContent(
                post: Post(
                    postId: 1,
                    teamId: 1,
                    userId: 1,
                    language: 'en',
                    category: PostCategory.general,
                    title: 'Post title',
                    body: url,
                    createdAt: ''),
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
                onReport: null,
                linkPreviewRepository: repository),
          ]))));
      await tester.pump();
      if (url.contains('x.com')) {
        platform.controllers.last.message('{"height":200}');
      }
      await tester.pumpAndSettle();
      final card = find.byType(CommunityLinkPreview);
      expect(
          tester.getTopLeft(card).dy -
              tester.getBottomLeft(find.text('Post title')).dy,
          24);
      expect(
          tester
                  .getTopLeft(find
                      .byKey(const ValueKey('community-detail-like-action')))
                  .dy -
              tester.getBottomLeft(card).dy,
          url.contains('x.com') ? 24 : 48);
      expect(tester.takeException(), isNull);
    }
  });
}
