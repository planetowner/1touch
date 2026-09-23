import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/HomeScreen.dart';

void main() {
  setUpAppCatalog();
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
    expect(find.text('Official channel 1h ago'), findsOneWidget);
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

  testWidgets('switches the favorite through the backend and refreshes Home',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final homeRepository = _ControlledHomeRepository();
    final followingRepository = _RecordingFollowingTeamsRepository();
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
          repository: homeRepository,
          newsRepository: _RecordingNewsRepository(),
          followingTeamsRepository: followingRepository,
        ),
      ),
    );
    homeRepository.calls.single.completer.complete(
      _homeData(
        favoriteTeam: const Team(teamId: 83, name: 'FC Barcelona'),
        followingTeams: const [
          Team(teamId: 83, name: 'FC Barcelona'),
          Team(teamId: 9, name: 'Manchester City'),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manchester City'));
    await tester.tap(find.text('SWITCH'));
    await tester.pumpAndSettle();

    expect(followingRepository.savedTeamIds, [83, 9]);
    expect(followingRepository.savedFavoriteTeamId, 9);
    expect(currentUserPreferences.favoriteTeamId.value, 9);
    expect(currentUserPreferences.followedTeamIds.value, [9, 83]);
    expect(homeRepository.calls, hasLength(2));

    homeRepository.calls.last.completer.complete(
      _homeData(
        favoriteTeam: const Team(teamId: 9, name: 'Manchester City'),
        followingTeams: const [
          Team(teamId: 83, name: 'FC Barcelona'),
          Team(teamId: 9, name: 'Manchester City'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Manchester City'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-brand-gradient')), findsNothing);
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
  );
}

class _HomeLoadCall {
  _HomeLoadCall({required this.start, required this.end});

  final DateTime? start;
  final DateTime? end;
  final Completer<HomeData> completer = Completer<HomeData>();
}

class _ControlledHomeRepository implements HomeRepository {
  final List<_HomeLoadCall> calls = [];

  @override
  Future<HomeData> load({DateTime? start, DateTime? end}) {
    final call = _HomeLoadCall(start: start, end: end);
    calls.add(call);
    return call.completer.future;
  }
}

class _RecordingFollowingTeamsRepository implements FollowingTeamsRepository {
  final ValueNotifier<List<Team>> _cache = ValueNotifier(const []);
  List<int>? savedTeamIds;
  int? savedFavoriteTeamId;

  @override
  ValueListenable<List<Team>> get cachedTeams => _cache;

  @override
  Future<List<Team>> load() async => _cache.value;

  @override
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  }) async {
    savedTeamIds = teamIds.toList();
    savedFavoriteTeamId = favoriteTeamId;
    const teams = [
      Team(teamId: 83, name: 'FC Barcelona'),
      Team(teamId: 9, name: 'Manchester City'),
    ];
    _cache.value = teams;
    return teams;
  }
}

class _RecordingNewsRepository implements NewsRepository {
  int loadCalls = 0;

  @override
  Future<List<HomeContentItem>> loadForTeam(
    int teamId, {
    required String language,
  }) async {
    loadCalls++;
    return const [_loadedContentItem];
  }
}

const _loadedContentItem = HomeContentItem(
  title: 'Repository content',
  source: 'Repository',
  timeLabel: 'Now',
);

const _apiHighlightItem = HomeContentItem(
  title: 'Official API highlight',
  source: 'Official channel',
  timeLabel: '1h ago',
  destinationUrl: 'https://www.youtube.com/watch?v=official',
);
