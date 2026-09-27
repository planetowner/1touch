import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/screens/PlayerScreen.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'support/player_detail_fixture.dart';
import 'support/player_directory_fixture.dart';

void main() {
  test('failed reload clears previous favorites and remains retryable',
      () async {
    final repository = FakeFollowingPlayersRepository();
    final controller = PlayerFollowingController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.contains(1), isTrue);

    repository.fail = true;
    await controller.load();
    expect(controller.players, isEmpty);
    expect(controller.loaded, isFalse);
    expect(controller.error, isA<StateError>());

    repository.fail = false;
    repository.players.value = [];
    await controller.load();
    expect(controller.loaded, isTrue);
    expect(controller.players, isEmpty);
    expect(controller.error, isNull);
  });

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(430, 932),
      bool dark = false,
      FakePlayerDirectoryRepository? repository,
      FakeFollowingPlayersRepository? following,
      FakePlayerDetailRepository? detailRepository}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: dark ? app_style.darktheme : app_style.whitetheme,
        home: Players(
            repository: repository ?? FakePlayerDirectoryRepository(),
            detailRepository: detailRepository ?? FakePlayerDetailRepository(),
            followingController: PlayerFollowingController(
                repository: following ?? FakeFollowingPlayersRepository()))));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets('real player directory fits $size dark=$dark',
          (tester) async {
        await pump(tester, size: size, dark: dark);
        expect(find.text('Favorite player'), findsOneWidget);
        expect(find.text('Ranked player 1'), findsOneWidget);
        expect(find.text('Ranked player 6'), findsNothing);
        expect(find.text('FAVORITE PLAYERS'), findsOneWidget);
        expect(find.byKey(const ValueKey('active-ranking-league-filter')),
            findsNothing);
        expect(find.byKey(const ValueKey('active-ranking-position-filter')),
            findsNothing);
        expect(
          tester.getSize(find.byKey(const ValueKey('players-profile-button'))),
          const Size.square(32),
        );
        expect(
          size.width -
              tester
                  .getTopRight(
                    find.byKey(const ValueKey('players-profile-button')),
                  )
                  .dx,
          24,
        );
        expect(
            find.byKey(const ValueKey('players-brand-gradient')), findsNothing);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(find.text('Improving player'), findsOneWidget);
        expect(find.byKey(const ValueKey('ones-to-watch-jersey-1')),
            findsOneWidget);
        expect(find.text('#17'), findsOneWidget);
        expect(find.text('2.20'), findsNothing);
        expect(find.text('+2.20'), findsNothing);
        expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
        expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('directory keeps the pre-merge card treatment with API data',
      (tester) async {
    await pump(tester);
    final ranking = tester.widget<Container>(
      find.byKey(const ValueKey('players-ranking-card')),
    );
    final decoration = ranking.decoration! as BoxDecoration;
    expect(ranking.padding, const EdgeInsets.all(24));
    expect(decoration.borderRadius, BorderRadius.circular(16));
    expect(decoration.boxShadow, app_style.lightModeCardShadows);
    expect(find.byKey(const ValueKey('favorite-player-number-badge')),
        findsNothing);
    expect(find.byIcon(Icons.help_outline), findsNWidgets(2));
  });

  testWidgets('main player search opens the shared search page',
      (tester) async {
    final followingController = PlayerFollowingController(
      repository: FakeFollowingPlayersRepository(),
    );
    addTearDown(followingController.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Players(
            repository: FakePlayerDirectoryRepository(),
            detailRepository: FakePlayerDetailRepository(),
            followingController: followingController,
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const Scaffold(
            key: ValueKey('shared-search-page'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('players-search-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('shared-search-page')),
      findsOneWidget,
    );
    expect(find.byType(PlayerPickerSheet), findsNothing);
  });

  testWidgets('ranking title sits 16px above its card without filters',
      (tester) async {
    await pump(tester);

    final titleBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('players-ranking-title-row')),
    );
    final cardTop = tester.getTopLeft(
      find.byKey(const ValueKey('players-ranking-card')),
    );

    expect(cardTop.dy - titleBottom.dy, 16);
  });

  testWidgets('active ranking filters have 16px spacing on both sides',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: PlayerRankingPanel(
            repository: FakePlayerDirectoryRepository(),
            league: 8,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleBottom = tester.getBottomLeft(
      find.byKey(const ValueKey('players-ranking-title-row')),
    );
    final filters = tester.getRect(
      find.byKey(const ValueKey('active-ranking-filters')),
    );
    final cardTop = tester.getTopLeft(
      find.byKey(const ValueKey('players-ranking-card')),
    );

    expect(filters.top - titleBottom.dy, 16);
    expect(cardTop.dy - filters.bottom, 16);
  });

  testWidgets('favorite players starts 24px below the app bar', (tester) async {
    await pump(tester);

    final appBar = find.descendant(
      of: find.byKey(const ValueKey('players-app-bar')),
      matching: find.byType(AppBar),
    );
    final appBarBottom = tester.getBottomLeft(appBar);
    final favoritesTop = tester.getTopLeft(
      find.byKey(const ValueKey('players-favorites-section')),
    );

    expect(favoritesTop.dy - appBarBottom.dy, 24);
  });

  testWidgets('pull refresh waits for every Players API request',
      (tester) async {
    final directory = _ControlledRefreshDirectoryRepository();
    final following = _ControlledRefreshFollowingRepository();
    await pump(tester, repository: directory, following: following);

    final indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    var completed = false;
    final refresh = indicator.onRefresh().whenComplete(() => completed = true);
    await tester.pump();

    expect(directory.rankingCalls, 2);
    expect(directory.watchCalls, 2);
    expect(following.loadCalls, 2);
    expect(completed, isFalse);

    following.refreshCompleter.complete(const []);
    await tester.pump();
    expect(completed, isFalse);

    directory.rankingRefreshCompleter.complete(
      const PlayerRankingPage(
        season: '2026/2027',
        leagues: [],
        items: [],
        total: 0,
      ),
    );
    await tester.pump();
    expect(completed, isFalse);

    directory.watchRefreshCompleter.complete(const []);
    await refresh;
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'league and position filters reach the API and unavailable league stays empty',
      (tester) async {
    final repository = FakePlayerDirectoryRepository();
    await pump(tester, repository: repository);
    expect(repository.calls.single, (league: null, position: null, offset: 0));
    await tester.tap(find.byTooltip('Ranking filters'));
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    await tester.tap(find.text('Bundesliga'));
    await tester.tap(find.text('Goalkeeper'));
    await tester.tap(find.text('UPDATE FILTER'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (league: 82, position: 'GK', offset: 0));
    expect(find.byKey(const ValueKey('active-ranking-league-filter')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('active-ranking-position-filter')),
        findsOneWidget);
    expect(find.text('BUNDESLIGA'), findsOneWidget);
    expect(find.text('GOALKEEPER'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(find.text('No ranking data for these filters'), findsOneWidget);
    expect(find.text('Ranked player 1'), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('active-ranking-position-filter')));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (league: 82, position: null, offset: 0));
    expect(find.byKey(const ValueKey('active-ranking-position-filter')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'favorite editor cancels without saving and saves authoritative list',
      (tester) async {
    final following = FakeFollowingPlayersRepository();
    await pump(tester, following: following);
    await tester.tap(find.byTooltip('Edit favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove player'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(following.saved, isNull);
    expect(find.text('Favorite player'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove player'));
    await tester.pump();
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();
    expect(following.saved, isEmpty);
    expect(find.text('Add favorite players'), findsOneWidget);
  });
  testWidgets('favorite editor shows search candidates without loading details',
      (tester) async {
    final detailRepository = FakePlayerDetailRepository();
    await pump(tester, detailRepository: detailRepository);
    expect(detailRepository.calls, isEmpty);

    await tester.tap(find.byTooltip('Edit favorites'));
    await tester.pumpAndSettle();
    expect(detailRepository.calls.length, 1);
    await tester.enterText(find.byType(TextField), 'Player');
    await tester.pumpAndSettle();

    expect(find.text('Player 1'), findsNothing);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('Player 3'), findsOneWidget);
    expect(detailRepository.calls.length, 1);

    await tester.tap(find.text('Player 2'));
    await tester.pump();
    final update = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'UPDATE'),
    );
    expect(update.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('directory retry restores real results', (tester) async {
    final repository = FakePlayerDirectoryRepository()..fail = true;
    await pump(tester, repository: repository);
    expect(find.text('Could not load ranking · Retry'), findsOneWidget);
    expect(find.text('Ranked player 1'), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Could not load ranking · Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ranked player 1'), findsOneWidget);
  });

  testWidgets('see all opens the restored ranking search sheet',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('full-ranking-sheet')), findsOneWidget);
    expect(find.text('1Touch Ranking'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Look for players'), findsOneWidget);
    expect(find.text('Ranked player 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ControlledRefreshDirectoryRepository
    extends FakePlayerDirectoryRepository {
  int rankingCalls = 0;
  int watchCalls = 0;
  final rankingRefreshCompleter = Completer<PlayerRankingPage>();
  final watchRefreshCompleter = Completer<List<PlayerWatch>>();

  @override
  Future<PlayerRankingPage> ranking({
    int? league,
    String? position,
    int offset = 0,
  }) {
    rankingCalls += 1;
    if (rankingCalls == 1) {
      return super.ranking(
        league: league,
        position: position,
        offset: offset,
      );
    }
    return rankingRefreshCompleter.future;
  }

  @override
  Future<List<PlayerWatch>> watch() {
    watchCalls += 1;
    if (watchCalls == 1) return super.watch();
    return watchRefreshCompleter.future;
  }
}

class _ControlledRefreshFollowingRepository
    extends FakeFollowingPlayersRepository {
  int loadCalls = 0;
  final refreshCompleter = Completer<List<FollowingPlayer>>();

  @override
  Future<List<FollowingPlayer>> load() {
    loadCalls += 1;
    if (loadCalls == 1) return super.load();
    return refreshCompleter.future;
  }
}
