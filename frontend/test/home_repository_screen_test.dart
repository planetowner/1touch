import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/features/home/screen/home_screen_features.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/HomeScreen.dart';

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
    final firstOffset = tester
        .widget<Transform>(
          find.byKey(const ValueKey('home-live-match-ball-motion')),
        )
        .transform
        .getTranslation()
        .x;
    await tester.pump(const Duration(milliseconds: 400));
    final nextOffset = tester
        .widget<Transform>(
          find.byKey(const ValueKey('home-live-match-ball-motion')),
        )
        .transform
        .getTranslation()
        .x;
    expect(nextOffset, isNot(firstOffset));

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('match 741 live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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

  testWidgets('calendar starts 16px below its title row', (tester) async {
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

    final titleRow = find.byKey(
      const ValueKey('home-calendar-title-row'),
    );
    final calendarCard = find.byKey(
      const ValueKey('fixture-calendar-card'),
    );

    expect(
      tester.getTopLeft(calendarCard).dy - tester.getBottomLeft(titleRow).dy,
      16,
    );
    expect(tester.takeException(), isNull);
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

  testWidgets('uses the reordered first followed team and preserves its order',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
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
        followingTeams: reorderedTeams,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FC Bayern München'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-app-bar-team-picker')));
    await tester.pumpAndSettle();

    final bayernTop =
        tester.getTopLeft(find.byKey(const ValueKey('team-selection-503'))).dy;
    final barcelonaTop =
        tester.getTopLeft(find.byKey(const ValueKey('team-selection-83'))).dy;
    expect(bayernTop, lessThan(barcelonaTop));
    expect(tester.takeException(), isNull);
  });

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
}) {
  return HomeData(
    favoriteTeam: favoriteTeam,
    followingTeams: followingTeams ??
        [
          favoriteTeam,
          const Team(teamId: 9, name: 'Beta FC'),
        ],
    nextMatch: null,
    lastMatch: null,
    calendar: const [],
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
