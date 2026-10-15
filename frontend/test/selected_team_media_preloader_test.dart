import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';
import 'package:onetouch/data/posts/api/api_post_repository.dart';
import 'package:onetouch/data/posts/api/api_post_draft_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/transfers/api/api_transfer_repository.dart';
import 'package:onetouch/features/media/selected_team_media_preloader.dart';
import 'package:onetouch/features/media/avatar_image_cache.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/features/community/community_link_preview.dart';
import 'package:onetouch/features/community/community_social_embed_cache.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'support/fake_webview_platform.dart';
import 'support/decoded_photo_cache.dart';
import 'package:onetouch/features/player/player_image_cache.dart';
import 'package:onetouch/features/team_screen_features.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/models/post.dart';

void main() {
  final cache = DecodedPhotoTestBinding().imageCache as DecodedPhotoCache;
  tearDown(cache.reset);
  tearDown(communitySocialEmbedCache.clear);

  testWidgets(
      'prepares social links from another tab and reuses the ready view on entry',
      (tester) async {
    final platform = FakeWebViewPlatform();
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = platform;
    addTearDown(
        () => WebViewPlatform.instance = previous ?? FakeWebViewPlatform());
    const url = 'https://www.instagram.com/p/Ready123/';
    const post = Post(
        postId: 1,
        teamId: 83,
        userId: 1,
        language: 'en',
        category: PostCategory.general,
        title: 'Post',
        body: url,
        createdAt: '');
    final api = _api((_) async => http.Response('Unavailable', 503));
    final showLink = ValueNotifier(false);
    addTearDown(showLink.dispose);
    await tester.pumpWidget(_app(SelectedTeamMediaPreloader(
      teamId: 83,
      draftRepository: ApiPostDraftRepository(api: api),
      postRepository: MockPostRepository(posts: [post]),
      injuryRepository: ApiTeamInjuryRepository(api: api),
      transferRepository: ApiTransferRepository(api: api),
      child: Scaffold(
          body: ValueListenableBuilder(
              valueListenable: showLink,
              builder: (_, visible, __) => visible
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: communityPostHorizontalPadding),
                      child: CommunityLinkPreview(uri: Uri.parse(url)))
                  : const Text('Another tab'))),
    )));
    await tester.pumpAndSettle();
    expect(platform.controllers.length, 1);
    platform.controllers.single.message('{"height":300}');
    showLink.value = true;
    await tester.pump();
    expect(tester.getSize(find.byType(WebViewWidget)).height, 300);
    expect(platform.controllers.length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('prepares each author once and reuses it on the first feed frame',
      (tester) async {
    const avatar = 'https://api.example.test/v1/users/1/avatar';
    final key = await registerDecodedPhoto(
        tester, cache, AvatarImageCache.provider(avatar));
    final posts = [
      for (var id = 1; id <= 2; id++)
        Post(
            postId: id,
            teamId: 83,
            language: 'en',
            userId: 1,
            category: PostCategory.general,
            title: 'Post $id',
            body: 'Text',
            createdAt: '2026-10-13T00:00:00Z',
            avatarUrl: avatar),
    ];
    final api = _api((_) async => http.Response('Unavailable', 503));
    final showFeed = ValueNotifier(false);
    addTearDown(showFeed.dispose);
    await tester.pumpWidget(_app(SelectedTeamMediaPreloader(
      teamId: 83,
      draftRepository: ApiPostDraftRepository(api: api),
      postRepository: MockPostRepository(posts: posts),
      injuryRepository: ApiTeamInjuryRepository(api: api),
      transferRepository: ApiTransferRepository(api: api),
      child: Scaffold(
          body: ValueListenableBuilder(
        valueListenable: showFeed,
        builder: (_, value, __) => value
            ? Column(children: [
                for (final post in posts)
                  CommunityAuthorHeader(
                      userId: post.userId,
                      username: 'member',
                      displayName: 'Member',
                      avatarUrl: avatar,
                      authorDeleted: false,
                      createdAt: post.createdAt)
              ])
            : const Text('Another tab'),
      )),
    )));
    await tester.pumpAndSettle();
    expect(cache.loads, {key: 1});
    showFeed.value = true;
    await tester.pump();
    for (final circle
        in tester.widgetList<CircleAvatar>(find.byType(CircleAvatar))) {
      expect(circle.backgroundImage, key);
      expect(PaintingBinding.instance.imageCache.statusForKey(key).keepAlive,
          isTrue);
    }
    expect(find.byType(CircleAvatar), findsNWidgets(2));
    expect(cache.loads, {key: 1});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'prepares both player lists from another tab and displays cached photos on entry',
      (tester) async {
    final keys = await _registerPhotos(tester, cache, 83);
    final transfersReady = Completer<http.Response>();
    final requests = <String, int>{};
    final api = _api((request) async {
      final path = request.url.path;
      requests.update(path, (count) => count + 1, ifAbsent: () => 1);
      if (path.endsWith('/injuries')) return _injuries(83);
      if (path.endsWith('/transfers')) return transfersReady.future;
      return http.Response('Community unavailable', 403);
    });
    final injuries = ApiTeamInjuryRepository(api: api);
    final transfers = ApiTransferRepository(api: api);
    final screen = ValueNotifier(0);
    addTearDown(screen.dispose);

    await tester.pumpWidget(_app(SelectedTeamMediaPreloader(
      teamId: 83,
      draftRepository: ApiPostDraftRepository(api: api),
      postRepository: ApiPostRepository(api: api),
      injuryRepository: injuries,
      transferRepository: transfers,
      child: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: screen,
          builder: (_, value, __) => value == 0
              ? const Text('Another tab')
              : SingleChildScrollView(
                  child: Column(children: [
                    InjuryStatus(teams: _team(83), repository: injuries),
                    Transfer(
                      teams: _team(83),
                      repository: transfers,
                      showIncoming: value == 1,
                    ),
                  ]),
                ),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Another tab'), findsOneWidget);
    expect(cache.loads, {keys[0]: 1});
    expect(requests['/v1/teams/83/transfers'], 1);

    transfersReady.complete(_transfers(83));
    await tester.pumpAndSettle();
    expect(cache.loads, {for (final key in keys) key: 1});

    for (final direction in [1, 2]) {
      screen.value = direction;
      // 준비가 끝난 뒤에는 첫 프레임부터 실제 사진이 나와야 해요.
      await tester.pump();
      expect(find.byKey(const ValueKey('injury-loading')), findsNothing);
      expect(find.byKey(const ValueKey('transfer-loading')), findsNothing);
      expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .where((image) => image.image != null),
          hasLength(2));
      // 사진이 없는 선수에게는 다른 선수 사진 대신 공통 아이콘을 보여줘요.
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      _expectNoMessi();
      expect(cache.loads, {for (final key in keys) key: 1});
    }
    expect(requests['/v1/teams/83/injuries'], 1);
    expect(requests['/v1/teams/83/transfers'], 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('team changes ignore old results and disposal stops preparation',
      (tester) async {
    final oldKeys = await _registerPhotos(tester, cache, 83);
    final newKeys = await _registerPhotos(tester, cache, 84);
    final disposedKeys = await _registerPhotos(tester, cache, 85);
    final pending = <String, Completer<http.Response>>{};
    final api = _api((request) =>
        (pending[request.url.path] ??= Completer<http.Response>()).future);
    final injuries = ApiTeamInjuryRepository(api: api);
    final transfers = ApiTransferRepository(api: api);
    final posts = MockPostRepository(posts: const []);
    final drafts = ApiPostDraftRepository(api: api);
    Widget subject(int teamId) => _app(SelectedTeamMediaPreloader(
          teamId: teamId,
          draftRepository: drafts,
          postRepository: posts,
          injuryRepository: injuries,
          transferRepository: transfers,
          child: const Scaffold(body: Text('Another tab')),
        ));
    void complete(int teamId) {
      pending['/v1/teams/$teamId/injuries']!.complete(_injuries(teamId));
      pending['/v1/teams/$teamId/transfers']!.complete(_transfers(teamId));
    }

    await tester.pumpWidget(subject(83));
    await tester.pump();
    await tester.pumpWidget(subject(84));
    await tester.pump();
    complete(83);
    await tester.pumpAndSettle();
    expect(oldKeys.any(cache.loads.containsKey), isFalse);
    complete(84);
    await tester.pumpAndSettle();
    expect(cache.loads, {for (final key in newKeys) key: 1});

    await tester.pumpWidget(subject(85));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    complete(85);
    await tester.pumpAndSettle();
    expect(disposedKeys.any(cache.loads.containsKey), isFalse);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
      theme: whitetheme,
      locale: const Locale('en'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600), devicePixelRatio: 2),
        child: child,
      ),
    );

ApiClient _api(Future<http.Response> Function(http.Request) respond) =>
    ApiClient(
      client: MockClient(respond),
      baseUri: Uri.parse('https://api.example.test/v1/'),
      requestHeaders: () => const {},
    );

TeamOverview _team(int id) =>
    TeamOverview(id: id, name: 'Team $id', shortName: 'T$id', imagePath: '');

String _url(int teamId, String kind) =>
    'https://images.example.test/$teamId/$kind.png';

http.Response _injuries(int teamId) => http.Response(
      jsonEncode({
        'team_id': teamId,
        'season_id': 1,
        'players': [
          for (final id in [1, 2])
            {
              'player_id': id,
              'player_name': 'Injured $id',
              'player_image': id == 1 ? ' ${_url(teamId, 'injury')} ' : null,
              'injuries': [
                {'sideline_id': id, 'type_id': 1, 'type_name': 'Knock'}
              ],
            },
        ],
      }),
      200,
    );

http.Response _transfers(int teamId) => http.Response(
      jsonEncode({
        'window_key': '2026 summer',
        for (final direction in ['in', 'out'])
          'transfers_$direction': [
            {
              'transfer_id': direction == 'in' ? 1 : 2,
              'player_id': direction == 'in' ? 3 : 4,
              'player_name': 'Transfer $direction',
              'player_image': _url(teamId, direction),
              'direction': direction,
              'type_id': 219,
              'display_type': 'Transfer',
            },
          ],
      }),
      200,
    );

Future<List<Object>> _registerPhotos(
    WidgetTester tester, DecodedPhotoCache cache, int teamId) async {
  return [
    for (final kind in ['injury', 'in', 'out'])
      await registerDecodedPhoto(
          tester,
          cache,
          PlayerImageCache.portraitProvider(_url(teamId, kind),
              devicePixelRatio: 2)),
  ];
}

void _expectNoMessi() {
  expect(
      find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/messi.png'),
      findsNothing);
}
