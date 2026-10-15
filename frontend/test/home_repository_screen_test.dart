import 'support/app_catalog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_repository.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/features/home/screen/home_screen_features.dart';
import 'package:onetouch/features/home/screen/live_match_ball_button.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/home_screen.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'package:onetouch/screens/PlayerScreen.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'support/stub_community_repository.dart';
import 'support/player_detail_fixture.dart';
import 'support/player_directory_fixture.dart';
import 'support/fixture_api_json.dart';

void main() {
  setUpAppCatalog();
  testWidgets('shows a rolling shortcut only for the viewed team live match',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final homeRepository = _ControlledHomeRepository();
    const liveFixture = Fixture(
      fixtureId: 741,
      seasonId: 1,
      competitionId: 1,
      homeTeamId: 83,
      awayTeamId: 9,
      competitionType: CompetitionType.league,
      roundName: '7',
      status: FixtureStatus.live,
      startingAt: null,
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => HomeScreen(
            repository: homeRepository,
            newsRepository: _RecordingNewsRepository(),
            fixtureRepository: MockFixtureRepository(
              fixtures: const [liveFixture],
            ),
          ),
        ),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) => Text(
            'match ${state.pathParameters['id']} ${state.uri.queryParameters['status']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: app_style.whitetheme, routerConfig: router),
    );
    homeRepository.calls.single.completer.complete(_homeData());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final button = find.byKey(const ValueKey('home-live-match-button'));
    expect(button, findsOneWidget);
    final firstRotation = tester
        .widget<Transform>(
          find.byKey(const ValueKey('home-live-match-ball-motion')),
        )
        .transform
        .storage[0];
    await tester.pump(const Duration(milliseconds: 400));
    final nextRotation = tester
        .widget<Transform>(
          find.byKey(const ValueKey('home-live-match-ball-motion')),
        )
        .transform
        .storage[0];
    expect(nextRotation, isNot(firstRotation));

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('match 741 live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final manualRefresh in [false, true]) {
    testWidgets(
        manualRefresh
            ? 'Home pull refresh waits for the latest live list and detail'
            : 'Home polling shows a newly live match on the first response',
        (tester) async {
      await _setScreenSize(tester, const Size(393, 852));
      final homeRepository = _ControlledHomeRepository();
      var serverFixture = {
        ...fixtureApiJson(fixtureId: 741),
        'home_team_id': 83,
        'away_team_id': 9,
      };
      final liveResponse = Completer<void>();
      final detailResponse = Completer<void>();
      var holdResponses = false;
      var detailRequested = false;
      final requests = <Uri>[];
      final api = ApiClient(
        baseUri: Uri.parse('http://localhost:8000/v1/'),
        requestHeaders: () => const {},
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/v1/fixtures/741') {
            detailRequested = true;
            await detailResponse.future;
            return http.Response(
                jsonEncode({
                  ...fixtureDetailApiJson(fixtureId: 741),
                  ...serverFixture,
                }),
                200);
          }
          if (holdResponses) await liveResponse.future;
          return http.Response(
              jsonEncode({
                'items':
                    serverFixture['status'] == 'live' ? [serverFixture] : [],
                'limit': 10,
                'offset': 0,
              }),
              200);
        }),
      );
      addTearDown(api.close);
      final repository = ApiFixtureRepository(api: api);
      Fixture fixture() =>
          fixtureFromApiResponse(ApiFixtureResponse.fromJson(serverFixture));
      HomeData home() => _homeData(
            nextMatch: serverFixture['status'] == 'upcoming' ? fixture() : null,
            calendar: [
              HomeCalendarFixture(
                fixture: fixture(),
                opponent: const Team(teamId: 9, name: 'Beta FC'),
              ),
            ],
          );

      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: homeRepository,
          newsRepository: _RecordingNewsRepository(),
          fixtureRepository: repository,
        ),
      ));
      homeRepository.calls.single.completer.complete(home());
      await tester.pump();
      await tester.pump();
      expect(
          repository.cachedForTeamMatches(83,
              status: FixtureStatus.live, limit: 10),
          isEmpty);
      expect(
          tester
              .widget<FavoriteTeamCard>(find.byType(FavoriteTeamCard))
              .team
              .liveMatch,
          isNull);

      serverFixture = {
        ...serverFixture,
        'status': 'live',
        'state_id': 2,
        'state_code': 'INPLAY_1ST_HALF',
      };
      holdResponses = true;
      var refreshCompleted = false;
      Future<void>? refresh;
      if (manualRefresh) {
        refresh = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh()
            .then((_) => refreshCompleted = true);
        await tester.pump();
        homeRepository.calls.last.completer.complete(home());
        await tester.pump();
        expect(refreshCompleted, isFalse);
      } else {
        await tester.pump(const Duration(seconds: 30));
      }

      expect(requests.last.path, '/v1/teams/83/matches');
      expect(requests.last.queryParameters['status'], 'live');
      liveResponse.complete();
      await tester.pump();
      await tester.pump();
      expect(detailRequested, isTrue);
      if (manualRefresh) expect(refreshCompleted, isFalse);

      detailResponse.complete();
      await tester.pump();
      await tester.pump();
      if (manualRefresh) {
        expect(refreshCompleted, isTrue);
        await refresh;
      }
      // 다음 30초 주기를 진행하지 않아도 최신 응답으로 카드가 전환돼야 해요.
      expect(
          tester
              .widget<FavoriteTeamCard>(find.byType(FavoriteTeamCard))
              .team
              .liveMatch
              ?.fixtureId,
          741);
      expect(
          find.byKey(const ValueKey('home-live-match-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('live ball makes three turns, pauses, then repeats',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LiveMatchBallButton(onPressed: () {})),
    ));
    await tester.pump();

    double horizontalRotation() => tester
        .widget<Transform>(
          find.byKey(const ValueKey('home-live-match-ball-motion')),
        )
        .transform
        .storage[0];

    expect(horizontalRotation(), closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 1042));
    expect(horizontalRotation(), closeTo(-1, 0.1));
    await tester.pump(const Duration(milliseconds: 1041));
    expect(horizontalRotation(), closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 600));
    expect(horizontalRotation(), closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 600));
    expect(horizontalRotation(), isNot(closeTo(1, 0.01)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('live ball stays still when animations are disabled',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: LiveMatchBallButton(onPressed: () {})),
      ),
    ));
    await tester.pump(const Duration(seconds: 4));
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('home-live-match-ball-motion')),
    );
    expect(transform.transform.storage[0], closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('live ball fits ${size.width.toInt()}px screen',
        (tester) async {
      await _setScreenSize(tester, size);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LiveMatchBallButton(onPressed: () {})),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.byKey(const ValueKey('home-live-match-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('loads Home and followed teams through the repository',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledHomeRepository();
    final newsRepository = _RecordingNewsRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: newsRepository,
        ),
      ),
    );

    expect(find.byType(FootballLoadingIndicator), findsOneWidget);
    expect(repository.calls, hasLength(1));
    final now = DateTime.now();
    expect(repository.calls.single.start, DateTime(now.year, now.month, 1));
    expect(
      repository.calls.single.end,
      DateTime(now.year, now.month + 1, 0),
    );

    repository.calls.single.completer.complete(_homeData());
    await tester.pump();

    expect(newsRepository.loadCalls, 1);
    expect(find.text('Alpha FC'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(find.text('Following Teams'), findsOneWidget);
    expect(find.text('Beta FC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retry state when the initial Home load fails',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );

    repository.calls.single.completer.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('Unable to load Home.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-retry-button')));
    await tester.pump();
    expect(repository.calls, hasLength(2));

    repository.calls.last.completer.complete(_homeData());
    await tester.pump();

    expect(find.text('Alpha FC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores a fresh viewed-team snapshot without another Home load',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _CachedHomeRepository();
    final originalFavorite = currentUserPreferences.favoriteTeamId.value;
    final originalFollowing = currentUserPreferences.followedTeamIds.value;
    addTearDown(() => currentUserPreferences.applyServerSelection(
          UserTeamPreferences(
            favoriteTeamId: originalFavorite,
            followedTeamIds: originalFollowing,
          ),
        ));
    currentUserPreferences.applyServerSelection(const UserTeamPreferences(
      favoriteTeamId: 83,
      followedTeamIds: [83, 9],
    ));

    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: HomeScreen(
        repository: repository,
        newsRepository: _RecordingNewsRepository(),
      ),
    ));
    repository.calls.last.completer.complete(_homeData());
    await tester.pump();

    currentUserPreferences.viewTeam(9);
    await tester.pump();
    repository.calls.last.completer.complete(
      _homeData(favoriteTeam: const Team(teamId: 9, name: 'Beta FC')),
    );
    await tester.pump();
    expect(find.text('Beta FC'), findsOneWidget);

    currentUserPreferences.viewTeam(83);
    await tester.pump();
    expect(repository.calls, hasLength(2));
    expect(find.text('Alpha FC'), findsOneWidget);
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final requiresRefresh in [false, true]) {
    testWidgets(
        'refreshes cached Home and preserves fixtures on failure, country refresh=$requiresRefresh',
        (tester) async {
      await _setScreenSize(tester, const Size(393, 852));
      final originalFavorite = currentUserPreferences.favoriteTeamId.value;
      final originalFollowing = currentUserPreferences.followedTeamIds.value;
      addTearDown(() => currentUserPreferences.applyServerSelection(
            UserTeamPreferences(
              favoriteTeamId: originalFavorite,
              followedTeamIds: originalFollowing,
            ),
          ));
      currentUserPreferences.applyServerSelection(const UserTeamPreferences(
        favoriteTeamId: 83,
        followedTeamIds: [83, 9],
      ));
      final repository = _CachedHomeRepository()
        ..saveSnapshot(
          83,
          DateTime.now(),
          _homeData(),
          savedAt: DateTime.now().subtract(
              requiresRefresh ? Duration.zero : const Duration(hours: 2)),
          requiresRefresh: requiresRefresh,
        );

      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ));
      expect(find.text('Alpha FC'), findsOneWidget);
      expect(find.byType(FootballLoadingIndicator), findsNothing);
      expect(repository.calls, hasLength(1));

      repository.calls.single.completer.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('Alpha FC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restores saved Home before a slow network refresh',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final originalFavorite = currentUserPreferences.favoriteTeamId.value;
    final originalFollowing = currentUserPreferences.followedTeamIds.value;
    addTearDown(() => currentUserPreferences.applyServerSelection(
          UserTeamPreferences(
            favoriteTeamId: originalFavorite,
            followedTeamIds: originalFollowing,
          ),
        ));
    currentUserPreferences.applyServerSelection(const UserTeamPreferences(
      favoriteTeamId: 83,
      followedTeamIds: [83, 9],
    ));
    final repository = _CachedHomeRepository()
      ..saveDiskSnapshot(
        83,
        DateTime.now(),
        _homeData(),
        savedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: HomeScreen(
        repository: repository,
        newsRepository: _RecordingNewsRepository(),
      ),
    ));
    await tester.pump();
    expect(find.text('Alpha FC'), findsOneWidget);
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(repository.calls, hasLength(1));

    repository.calls.single.completer.complete(_homeData());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull refresh reloads Home data and news', (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();
    final newsRepository = _RecordingNewsRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: newsRepository,
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();

    final indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    final refresh = indicator.onRefresh();
    await tester.pump();

    expect(repository.calls, hasLength(2));
    expect(newsRepository.loadCalls, 2);

    repository.calls.last.completer.complete(_homeData());
    await refresh;
    await tester.pumpAndSettle();

    expect(find.text('Alpha FC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home tab action returns the root screen to the top',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();

    final scrollView =
        tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(scrollView.controller!.offset, greaterThan(0));

    mainTabActions.select(0);
    await tester.pumpAndSettle();

    expect(scrollView.controller!.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders official Home highlights instead of feed highlights',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Official API highlight'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Official API highlight'), findsOneWidget);
    expect(find.text('Official channel · Latest'), findsOneWidget);
  });

  testWidgets('home app bar uses the shared app logo size and spacing',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();

    final logo = tester.getRect(
      find.byKey(const ValueKey('home-app-bar-logo')),
    );
    final search = tester.getRect(
      find.byKey(const ValueKey('home-app-bar-search')),
    );
    final teamPicker = tester.getRect(
      find.byKey(const ValueKey('home-app-bar-team-picker')),
    );
    final profile = tester.getRect(
      find.byKey(const ValueKey('home-app-bar-profile')),
    );

    expect(logo.left, 24);
    expect(logo.width, closeTo(113.2308, 0.001));
    expect(logo.height, 23);
    expect(search.size, const Size(32, 32));
    expect(teamPicker.size, const Size(64, 40));
    expect(profile.size, const Size(32, 32));
    expect(teamPicker.left - search.right, 16);
    expect(profile.left - teamPicker.right, 16);
    expect(393 - profile.right, 24);
    final pickerDecoration = tester
        .widget<Container>(
          find.byKey(const ValueKey('home-app-bar-team-picker')),
        )
        .decoration as BoxDecoration;
    expect(pickerDecoration.color, Colors.white);
    expect(pickerDecoration.boxShadow, app_style.lightModeCardShadows);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Korean community and players retain the home brand geometry',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    tester.view.padding = const FakeViewPadding(top: 59);
    tester.view.viewPadding = const FakeViewPadding(top: 59);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = const Locale('en'));
    Widget shell(Widget child) => MaterialApp(
          theme: app_style.whitetheme,
          locale: const Locale('ko'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: child,
        );
    final repository = _ControlledHomeRepository();
    await tester.pumpWidget(shell(HomeScreen(
      repository: repository,
      newsRepository: _RecordingNewsRepository(),
    )));
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();
    final homeLogo =
        tester.getRect(find.byKey(const ValueKey('home-app-bar-logo')));
    final homeSearch =
        tester.getRect(find.byKey(const ValueKey('home-app-bar-search')));
    final following =
        PlayerFollowingController(repository: FakeFollowingPlayersRepository());
    addTearDown(following.dispose);
    for (final (screen, logoKey, searchKey, lastKey) in [
      (
        Community(
            teamId: 9,
            postRepository: MockPostRepository(),
            communityRepository: const StubCommunityRepository()),
        'community-app-logo',
        'community-search-button',
        'community-activity-button',
      ),
      (
        Players(
            repository: FakePlayerDirectoryRepository(),
            detailRepository: FakePlayerDetailRepository(),
            followingController: following),
        'players-app-logo',
        'players-search-button',
        'players-profile-button',
      ),
    ]) {
      await tester.pumpWidget(shell(screen));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(ValueKey(logoKey))), homeLogo);
      final search = tester.getRect(find.byKey(ValueKey(searchKey)));
      expect(search.size, homeSearch.size);
      expect(search.center.dy, homeSearch.center.dy);
      final last = tester.getRect(find.byKey(ValueKey(lastKey)));
      expect(last.right, 393 - 24);
      expect(last.center.dx - search.center.dx, 96);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('home team picker shadow extends past the 48px toolbar',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    tester.view.padding = const FakeViewPadding(top: 59);
    tester.view.viewPadding = const FakeViewPadding(top: 59);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      final repository = _ControlledHomeRepository();
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            theme: app_style.whitetheme,
            home: HomeScreen(
                repository: repository,
                newsRepository: _RecordingNewsRepository())),
      ));
      repository.calls.single.completer.complete(_homeData());
      await tester.pumpAndSettle();
      final toolbar = tester.getRect(find.byType(NavigationToolbar));
      final picker = tester
          .getRect(find.byKey(const ValueKey('home-app-bar-team-picker')));
      expect(toolbar.height, 48);
      expect(picker.size, const Size(64, 40));
      expect(picker.center.dy, toolbar.center.dy);
      final pixels = await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return bytes!;
      });
      final y = toolbar.bottom.toInt() + 6;
      final shadow = pixels!.getUint8((y * 393 + picker.center.dx.toInt()) * 4);
      final background = pixels.getUint8((y * 393 + 24) * 4);
      // 장식 값만 확인하면 상위 ClipRect가 실제 그림자를 자르는 회귀를 놓쳐요.
      expect(shadow, lessThan(background - 2));
      final controller = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      controller.jumpTo(120);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('home-app-bar-team-picker')).hitTestable(),
          findsNothing);
      mainTabActions.select(0);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(NavigationToolbar)), toolbar);
      expect(tester.takeException(), isNull);
    } finally {
      debugDisableShadows = previousShadows;
    }
  });

  testWidgets('home team picker keeps its dark mode surface', (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();

    final picker = find.byKey(const ValueKey('home-app-bar-team-picker'));
    final decoration =
        tester.widget<Container>(picker).decoration as BoxDecoration;
    expect(tester.getSize(picker), const Size(64, 40));
    expect(decoration.color, Colors.white.withValues(alpha: 0.2));
    expect(decoration.boxShadow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorite team header starts 48px below the home app bar',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();

    final appBar = tester.getRect(
      find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.byType(NavigationToolbar),
      ),
    );
    final favoriteTeamHeader = tester.getRect(
      find.byKey(const ValueKey('home-favorite-team-header')),
    );

    expect(favoriteTeamHeader.top - appBar.bottom, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news title starts 48px below the final highlight card',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pumpAndSettle();

    final newsTitle = find.byKey(const ValueKey('home-news-title'));
    await tester.scrollUntilVisible(
      newsTitle,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final highlightCard = find.byKey(
      const ValueKey('https://www.youtube.com/watch?v=official-0'),
    );
    expect(
      tester.getTopLeft(newsTitle).dy - tester.getBottomLeft(highlightCard).dy,
      48,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar title and right-aligned sync icon sit above the card',
      (tester) async {
    for (final size in [const Size(320, 568), const Size(393, 852)]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _setScreenSize(tester, size);
      final repository = _ControlledHomeRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.whitetheme,
          home: HomeScreen(
            repository: repository,
            newsRepository: _RecordingNewsRepository(),
          ),
        ),
      );
      repository.calls.single.completer.complete(_homeData());
      await tester.pumpAndSettle();

      final titleRow = find.byKey(const ValueKey('home-calendar-title-row'));
      final heading = find.descendant(
        of: titleRow,
        matching: find.text('CALENDAR'),
      );
      final syncIcon = find.descendant(
        of: titleRow,
        matching: find.byIcon(Icons.sync),
      );
      final calendarCard = find.byKey(
        const ValueKey('fixture-calendar-card'),
      );

      expect(
        tester.getCenter(heading).dy,
        closeTo(tester.getCenter(syncIcon).dy, 0.1),
      );
      expect(
        tester.getRect(titleRow).right - tester.getRect(syncIcon).right,
        0,
      );
      expect(
        tester.getSize(find.ancestor(
          of: syncIcon,
          matching: find.byType(IconButton),
        )),
        const Size(48, 48),
      );
      expect(
        tester.getTopLeft(calendarCard).dy - tester.getBottomLeft(syncIcon).dy,
        16,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reloads calendar months and ignores a stale response',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(repository.calls, hasLength(3));
    final now = DateTime.now();
    expect(
      repository.calls[1].start,
      DateTime(now.year, now.month + 1, 1),
    );
    expect(repository.calls[2].start, DateTime(now.year, now.month, 1));

    repository.calls[2].completer.complete(_homeData());
    await tester.pump();
    repository.calls[1].completer.complete(
      _homeData(favoriteTeam: const Team(teamId: 3, name: 'Late FC')),
    );
    await tester.pump();

    expect(find.text('Alpha FC'), findsOneWidget);
    expect(find.text('Late FC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes previously displayed Home data when reloading fails',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pump();
    expect(find.text('Alpha FC'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    repository.calls.last.completer.completeError(StateError('invalid home'));
    await tester.pump();

    expect(find.text('Unable to load Home.'), findsOneWidget);
    expect(find.text('Alpha FC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refreshes the team dropdown when followed teams change',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();
    final originalFavorite = currentUserPreferences.favoriteTeamId.value;
    final originalFollowing = currentUserPreferences.followedTeamIds.value;
    addTearDown(() {
      unawaited(
        currentUserPreferences.updateTeamSelection([
          originalFavorite,
          ...originalFollowing.where((id) => id != originalFavorite),
        ]),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          newsRepository: _RecordingNewsRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(
      _homeData(
        favoriteTeam: const Team(teamId: 83, name: 'FC Barcelona'),
        followingTeams: const [
          Team(teamId: 83, name: 'FC Barcelona'),
          Team(teamId: 19, name: 'Arsenal'),
        ],
      ),
    );
    await tester.pump();

    unawaited(currentUserPreferences.updateTeamSelection(const [83, 503]));
    await tester.pump();

    expect(repository.calls, hasLength(2));
    repository.calls.last.completer.complete(
      _homeData(
        favoriteTeam: const Team(teamId: 83, name: 'FC Barcelona'),
        followingTeams: const [
          Team(teamId: 83, name: 'FC Barcelona'),
          Team(teamId: 503, name: 'FC Bayern München'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(find.text('FC Bayern München'), findsOneWidget);
    expect(find.text('Arsenal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('Home picker follows profile team order at $size',
        (tester) async {
      await _setScreenSize(tester, size);
      final repository = _ControlledHomeRepository();
      const reorderedTeams = [
        Team(teamId: 503, name: 'FC Bayern München'),
        Team(teamId: 83, name: 'FC Barcelona'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.whitetheme,
          home: HomeScreen(
            repository: repository,
            newsRepository: _RecordingNewsRepository(),
          ),
        ),
      );
      repository.calls.single.completer.complete(
        _homeData(
          favoriteTeam: const Team(teamId: 83, name: 'FC Barcelona'),
          followingTeams: reorderedTeams.reversed.toList(),
        ),
      );
      await tester.pumpAndSettle();

      currentUserPreferences.applyServerSelection(const UserTeamPreferences(
        favoriteTeamId: 503,
        followedTeamIds: [503, 83],
      ));
      currentUserPreferences.resetViewedTeam();
      await tester.pump();

      expect(repository.calls.last.teamId, 503);
      repository.calls.last.completer.complete(
        _homeData(
          favoriteTeam: reorderedTeams.first,
          followingTeams: reorderedTeams.reversed.toList(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('FC Bayern München'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-app-bar-team-picker')));
      await tester.pumpAndSettle();

      final bayernTop = tester
          .getTopLeft(find.byKey(const ValueKey('team-selection-503')))
          .dy;
      final barcelonaTop =
          tester.getTopLeft(find.byKey(const ValueKey('team-selection-83'))).dy;
      expect(bayernTop, lessThan(barcelonaTop));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('switches viewed teams repeatedly without changing preferences',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final homeRepository = _ControlledHomeRepository();
    final newsRepository = _RecordingNewsRepository();
    final originalFavorite = currentUserPreferences.favoriteTeamId.value;
    final originalFollowing = currentUserPreferences.followedTeamIds.value;
    const teams = [
      Team(teamId: 83, name: 'FC Barcelona'),
      Team(teamId: 503, name: 'FC Bayern München'),
      Team(teamId: 9, name: 'Manchester City'),
    ];
    currentUserPreferences.applyServerSelection(const UserTeamPreferences(
      favoriteTeamId: 83,
      followedTeamIds: [83, 503, 9],
    ));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      currentUserPreferences.applyServerSelection(UserTeamPreferences(
        favoriteTeamId: originalFavorite,
        followedTeamIds: originalFollowing,
      ));
    });
    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: HomeScreen(
        repository: homeRepository,
        newsRepository: newsRepository,
      ),
    ));
    expect(homeRepository.calls.single.teamId, 83);
    homeRepository.calls.single.completer.complete(_homeData(
      favoriteTeam: teams.first,
      followingTeams: teams,
    ));
    await tester.pumpAndSettle();

    for (final team in [teams[2], teams[1], teams[0]]) {
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(team.name).last);
      await tester.tap(find.text('SWITCH'));
      await tester.pump();
      expect(homeRepository.calls.last.teamId, team.teamId);
      homeRepository.calls.last.completer.complete(_homeData(
        favoriteTeam: team,
        followingTeams: teams,
        leaguePosition: team.teamId == 9 ? 2 : 1,
        leagueRankDelta: team.teamId == 9 ? -1 : 2,
      ));
      await tester.pumpAndSettle();
      expect(find.text(team.name), findsOneWidget);
      final standing =
          tester.widget<Text>(find.byKey(const ValueKey('home-team-standing')));
      expect(standing.data, endsWith(team.teamId == 9 ? '2nd' : '1st'));
      expect(find.byKey(const ValueKey('home-team-rank-movement')),
          findsOneWidget);
      expect(newsRepository.teamIds.last, team.teamId);
      expect(currentUserPreferences.favoriteTeamId.value, 83);
      expect(currentUserPreferences.followedTeamIds.value, [83, 503, 9]);
      expect(find.text('FAVORITE TEAM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(homeRepository.calls, hasLength(4));
  });

  testWidgets('keeps the viewed team for calendar and preference refreshes',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final homeRepository = _ControlledHomeRepository();
    const teams = [
      Team(teamId: 83, name: 'FC Barcelona'),
      Team(teamId: 503, name: 'FC Bayern München'),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: HomeScreen(
        repository: homeRepository,
        newsRepository: _RecordingNewsRepository(),
      ),
    ));
    homeRepository.calls.last.completer
        .complete(_homeData(favoriteTeam: teams.first, followingTeams: teams));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FC Bayern München'));
    await tester.tap(find.text('SWITCH'));
    await tester.pump();
    homeRepository.calls.last.completer
        .complete(_homeData(favoriteTeam: teams.last, followingTeams: teams));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.sync));
    await tester.tap(find.byIcon(Icons.sync));
    await tester.pumpAndSettle();
    final syncDialog = tester.widget<SyncDialog>(find.byType(SyncDialog));
    expect(syncDialog.teamId, 503);
    expect(syncDialog.teamName, contains('Bayern'));
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(homeRepository.calls.last.teamId, 503);
    homeRepository.calls.last.completer
        .complete(_homeData(favoriteTeam: teams.last, followingTeams: teams));
    await tester.pumpAndSettle();

    currentUserPreferences.applyServerSelection(const UserTeamPreferences(
        favoriteTeamId: 19, followedTeamIds: [19, 83, 503]));
    await tester.pump();
    expect(homeRepository.calls.last.teamId, 503);
    homeRepository.calls.last.completer
        .complete(_homeData(favoriteTeam: teams.last, followingTeams: teams));
    await tester.pumpAndSettle();

    currentUserPreferences.applyServerSelection(const UserTeamPreferences(
        favoriteTeamId: 19, followedTeamIds: [19, 83]));
    await tester.pump();
    expect(homeRepository.calls.last.teamId, 19);
    homeRepository.calls.last.completer.complete(
        _homeData(favoriteTeam: const Team(teamId: 19, name: 'Arsenal')));
    await tester.pumpAndSettle();
    tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Arsenal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

HomeData _homeData({
  Team favoriteTeam = const Team(teamId: 83, name: 'Alpha FC'),
  List<Team>? followingTeams,
  List<HomeContentItem> highlights = const [_apiHighlightItem],
  int? leaguePosition,
  int? leagueRankDelta,
  Fixture? nextMatch,
  List<HomeCalendarFixture> calendar = const [],
}) {
  return HomeData(
    favoriteTeam: favoriteTeam,
    followingTeams: followingTeams ??
        [
          favoriteTeam,
          const Team(teamId: 9, name: 'Beta FC'),
        ],
    nextMatch: nextMatch,
    lastMatch: null,
    calendar: calendar,
    highlights: highlights,
    leaguePosition: leaguePosition,
    leagueRankDelta: leagueRankDelta,
  );
}

class _HomeLoadCall {
  _HomeLoadCall({this.teamId, required this.start, required this.end});

  final int? teamId;

  final DateTime? start;
  final DateTime? end;
  final Completer<HomeData> completer = Completer<HomeData>();
}

class _ControlledHomeRepository implements HomeRepository {
  final List<_HomeLoadCall> calls = [];

  @override
  Future<HomeData> load({int? teamId, DateTime? start, DateTime? end}) {
    final call = _HomeLoadCall(teamId: teamId, start: start, end: end);
    calls.add(call);
    return call.completer.future;
  }
}

class _CachedHomeRepository extends _ControlledHomeRepository
    implements HomeSnapshotRepository {
  final _snapshots = <(int, int, int), HomeSnapshot>{};
  final _diskSnapshots = <(int, int, int), HomeSnapshot>{};

  void saveSnapshot(int teamId, DateTime month, HomeData data,
      {required DateTime savedAt, bool requiresRefresh = false}) {
    _snapshots[(teamId, month.year, month.month)] =
        HomeSnapshot(data, savedAt, requiresRefresh: requiresRefresh);
  }

  void saveDiskSnapshot(int teamId, DateTime month, HomeData data,
      {required DateTime savedAt}) {
    _diskSnapshots[(teamId, month.year, month.month)] =
        HomeSnapshot(data, savedAt);
  }

  @override
  HomeSnapshot? snapshotFor({required int teamId, required DateTime month}) =>
      _snapshots[(teamId, month.year, month.month)];

  @override
  Future<HomeSnapshot?> restoreFor({
    required int teamId,
    required DateTime month,
  }) async =>
      _diskSnapshots[(teamId, month.year, month.month)];

  @override
  void clearSnapshots() => _snapshots.clear();

  @override
  Future<HomeData> load({int? teamId, DateTime? start, DateTime? end}) async {
    final data = await super.load(teamId: teamId, start: start, end: end);
    if (teamId != null && start != null) {
      _snapshots[(teamId, start.year, start.month)] =
          HomeSnapshot(data, DateTime.now());
    }
    return data;
  }
}

class _RecordingNewsRepository implements NewsRepository {
  final teamIds = <int>[];
  int get loadCalls => teamIds.length;

  @override
  Future<List<HomeContentItem>> loadForTeam(
    int teamId, {
    required String language,
  }) async {
    teamIds.add(teamId);
    return const [_loadedContentItem];
  }
}

const _loadedContentItem = HomeContentItem(
  title: 'Repository content',
  source: 'Repository',
  publishedAt: null,
);

const _apiHighlightItem = HomeContentItem(
  title: 'Official API highlight',
  source: 'Official channel',
  publishedAt: null,
  destinationUrl: 'https://www.youtube.com/watch?v=official',
);
