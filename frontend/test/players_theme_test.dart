import 'dart:async';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/screens/PlayerScreen.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/player/player_directory_sheets.dart';
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/l10n/app_localizations.dart';
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
      Locale locale = const Locale('en'),
      FakePlayerDirectoryRepository? repository,
      FakeFollowingPlayersRepository? following,
      FakePlayerDetailRepository? detailRepository}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appLocaleController.value = locale;
    addTearDown(() => appLocaleController.value = const Locale('en'));
    await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
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
        expect(
          find.byKey(const ValueKey('favorite-player-number-1')),
          findsOneWidget,
        );
        expect(find.text('7'), findsOneWidget);
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
        expect(find.text('Improving\nplayer'), findsOneWidget);
        expect(find.text('Atlético de Madrid'), findsOneWidget);
        expect(find.textContaining('Rating '), findsNothing);
        expect(find.byKey(const ValueKey('ones-to-watch-jersey-1')),
            findsOneWidget);
        expect(find.text('17'), findsOneWidget);
        expect(find.text('2.20'), findsNothing);
        expect(find.text('+2.20'), findsNothing);
        expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
        expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'player lists render and scroll without requesting player details',
      (tester) async {
    final details = FakePlayerDetailRepository()..fail = true;
    await pump(tester, detailRepository: details);
    expect(
        find.byKey(const ValueKey('favorite-player-number-1')), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Atlético de Madrid'), findsOneWidget);
    expect(details.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ones to watch cards keep equal heights for one- and two-line names',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayersToWatch(
          repository: _TwoWatchDirectoryRepository(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Improving\nplayer'), findsOneWidget);
    expect(find.text('Neymar'), findsOneWidget);
    expect(find.text('Atlético de Madrid'), findsNWidgets(2));
    final cards = find.byKey(const ValueKey('ones-to-watch-card'));
    expect(cards, findsNWidgets(2));
    for (var index = 0; index < 2; index++) {
      expect(tester.getSize(cards.at(index)), const Size(150, 200));
      final portrait = tester.getRect(
        find.byKey(ValueKey('ones-to-watch-portrait-${index + 1}')),
      );
      final jersey = tester.getRect(
        find.byKey(ValueKey('ones-to-watch-jersey-${index + 1}')),
      );
      final imageSurface = tester.getRect(
        find.byKey(const ValueKey('ones-to-watch-image-surface')).at(index),
      );
      expect(portrait.top, jersey.top);
      expect(portrait.bottom, imageSurface.bottom);
      expect(portrait.width, imageSurface.height - 10);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('directory keeps the pre-merge card treatment with API data',
      (tester) async {
    await pump(tester);
    final ranking = tester.widget<Container>(
      find.byKey(const ValueKey('players-ranking-card')),
    );
    final decoration = ranking.decoration! as BoxDecoration;
    expect(ranking.padding,
        const EdgeInsets.symmetric(horizontal: 24, vertical: 16));
    expect(decoration.borderRadius, BorderRadius.circular(16));
    expect(decoration.boxShadow, app_style.lightModeCardShadows);
    final badge = find.byKey(const ValueKey('favorite-player-number-1'));
    final circle = find.byKey(const ValueKey('favorite-player-circle-1'));
    expect(badge, findsOneWidget);
    expect(tester.getSize(badge), const Size.square(32));
    expect(tester.getTopLeft(circle) - tester.getTopLeft(badge),
        const Offset(5, 5));
    expect(find.byIcon(Icons.help_outline), findsNWidgets(2));
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('ranking card and sheet share row spacing at $size',
        (tester) async {
      await pump(tester, size: size, dark: true);
      final card = find.byKey(const ValueKey('players-ranking-card'));
      final firstRow = find.byKey(const ValueKey('ranking-player-1'));
      final secondRow = find.byKey(const ValueKey('ranking-player-2'));
      final seeAll = find.text('See all');

      expect(tester.getRect(firstRow).top - tester.getRect(card).top, 16);
      expect(tester.getRect(firstRow).height, 56);
      expect(
        tester
            .getCenter(
              find
                  .descendant(of: firstRow, matching: find.byType(Column))
                  .first,
            )
            .dy,
        closeTo(
          tester
              .getCenter(
                find
                    .descendant(of: firstRow, matching: find.byType(ClipOval))
                    .first,
              )
              .dy,
          0.5,
        ),
      );
      expect(
          tester.getRect(secondRow).top - tester.getRect(firstRow).bottom, 16);
      expect(
          tester.getRect(seeAll).top -
              tester
                  .getRect(find.byKey(const ValueKey('ranking-player-5')))
                  .bottom,
          24);
      expect(tester.getRect(card).bottom - tester.getRect(seeAll).bottom, 16);

      await tester.ensureVisible(seeAll);
      await tester.pumpAndSettle();
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('full-ranking-sheet'));
      final search = find.byKey(const ValueKey('full-ranking-search'));
      final fullFirstRow = find.byKey(const ValueKey('full-ranking-player-1'));
      final fullSecondRow = find.byKey(const ValueKey('full-ranking-player-2'));
      expect(tester.getRect(search).height, 40);
      expect(tester.getRect(search).left - tester.getRect(sheet).left, 24);
      expect(tester.getRect(sheet).right - tester.getRect(search).right, 24);
      expect(
          tester.getRect(fullFirstRow).top - tester.getRect(search).bottom, 24);
      expect(tester.getRect(fullFirstRow).height, 56);
      expect(
        tester
            .getCenter(
              find
                  .descendant(of: fullFirstRow, matching: find.byType(Column))
                  .first,
            )
            .dy,
        closeTo(
          tester
              .getCenter(
                find
                    .descendant(
                      of: fullFirstRow,
                      matching: find.byType(ClipOval),
                    )
                    .first,
              )
              .dy,
          0.5,
        ),
      );
      expect(
          tester.getRect(fullSecondRow).top -
              tester.getRect(fullFirstRow).bottom,
          16);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('expanded ranking keeps rank 100 on one aligned line at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: PlayerFullRankingSheet(
            players: [
              for (final rank in [99, 100])
                (
                  id: rank,
                  name: 'Player $rank',
                  image: null,
                  position: 'FW',
                  rank: rank,
                  score: 99.0,
                  rating: 99.0,
                  appearances: 10,
                ),
            ],
            followingController: null,
            detailRepository: FakePlayerDetailRepository(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final ranks = [
        for (final rank in [99, 100])
          find.descendant(
            of: find.byKey(ValueKey('full-ranking-player-$rank')),
            matching: find.text('$rank'),
          ),
      ];
      final first = tester.widget<Text>(ranks.first);
      final second = tester.widget<Text>(ranks.last);
      expect(first.maxLines, 1);
      expect(second.maxLines, 1);
      expect(second.softWrap, isFalse);
      expect(tester.getRect(ranks.first).left, tester.getRect(ranks.last).left);
      expect(tester.getRect(ranks.first).height,
          tester.getRect(ranks.last).height);
      for (final rank in [99, 100]) {
        final row = find.byKey(ValueKey('full-ranking-player-$rank'));
        final label = find.descendant(of: row, matching: find.text('$rank'));
        expect(tester.getCenter(label).dy, tester.getCenter(row).dy);
      }
      expect(tester.takeException(), isNull);
    });
  }

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

  testWidgets('ranking shows cached first page while request is pending',
      (tester) async {
    final cached = PlayerRankingPage(
      season: '2026/2027',
      leagues: const [],
      items: const [
        (
          id: 301,
          name: 'Cached rank',
          image: null,
          position: 'DF',
          rank: 1,
          score: 84.0,
          rating: 7.5,
          appearances: 12,
        ),
      ],
      total: 1,
    );
    final repository = _PendingCachedRankingRepository()..seedRanking(cached);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PlayerRankingPanel(repository: repository)),
    ));

    expect(find.text('Cached rank'), findsOneWidget);
    expect(find.byType(FootballLoadingIndicator), findsNothing);

    final fresh = PlayerRankingPage(
      season: '2026/2027',
      leagues: const [],
      items: const [
        (
          id: 301,
          name: 'Fresh rank',
          image: null,
          position: 'DF',
          rank: 1,
          score: 85.0,
          rating: 7.6,
          appearances: 13,
        ),
      ],
      total: 1,
    );
    repository.seedRanking(fresh);
    await tester.pump();
    expect(find.text('Fresh rank'), findsOneWidget);

    // An older load result must not replace a newer cache publication.
    repository.pending.complete(cached);
    await tester.pumpAndSettle();
    expect(find.text('Fresh rank'), findsOneWidget);
    expect(find.text('Cached rank'), findsNothing);
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
    final details = FakePlayerDetailRepository()..fail = true;
    await pump(tester,
        repository: directory, following: following, detailRepository: details);

    final indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    var completed = false;
    final refresh = indicator.onRefresh().whenComplete(() => completed = true);
    await tester.pump();

    expect(directory.rankingCalls, 2);
    expect(directory.watchCalls, 2);
    expect(following.loadCalls, 2);
    expect(completed, isFalse);

    following.refreshCompleter.complete(const [
      FollowingPlayer(
          playerId: 1,
          name: 'Favorite player',
          imagePath: null,
          jerseyNumber: 12),
    ]);
    await tester.pump();
    expect(completed, isFalse);

    directory.rankingRefreshCompleter.complete(
      PlayerRankingPage(
        season: '2026/2027',
        leagues: [],
        items: [],
        total: 0,
      ),
    );
    await tester.pump();
    expect(completed, isFalse);

    directory.watchRefreshCompleter.complete(const [
      (
        id: 1,
        name: 'Improving player',
        image: null,
        jerseyNumber: 31,
        teamId: null,
        teamName: 'Updated club',
        recent: 8.4,
        previous: 6.2,
        change: 2.2
      ),
    ]);
    await refresh;
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('favorite-player-number-1')),
            matching: find.text('12')),
        findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Updated club'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(details.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favorites retry reloads jersey numbers after a failed refresh',
      (tester) async {
    final following = FakeFollowingPlayersRepository();
    final details = FakePlayerDetailRepository()..fail = true;
    await pump(tester, following: following, detailRepository: details);
    following.fail = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Could not load favorites · Retry'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('favorite-player-number-1')), findsNothing);

    following.fail = false;
    following.players.value = const [
      FollowingPlayer(
          playerId: 1,
          name: 'Favorite player',
          imagePath: null,
          jerseyNumber: 12),
      FollowingPlayer(playerId: 2, name: 'No number', imagePath: null),
    ];
    await tester.tap(find.text('Could not load favorites · Retry'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('favorite-player-number-1')),
            matching: find.text('12')),
        findsOneWidget);
    expect(find.text('No number'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('favorite-player-number-2')), findsNothing);
    expect(details.calls, isEmpty);
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
    expect(
        find.byKey(const ValueKey('players-empty-favorites')), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets('empty favorites card fits $size dark=$dark', (tester) async {
        final following = FakeFollowingPlayersRepository()..players.value = [];
        await pump(tester,
            size: size,
            dark: dark,
            locale: const Locale('ko'),
            following: following);

        final card = find.byKey(const ValueKey('players-empty-favorites'));
        final border = find.ancestor(
          of: card,
          matching: find.byType(DottedBorder),
        );
        final message = find.text('팔로우 하는 선수가 아직 없어요.\n지금 추가해보세요.');
        expect(card, findsOneWidget);
        expect(border, findsOneWidget);
        expect(message, findsOneWidget);
        expect(tester.getRect(border).left, closeTo(24, 0.1));
        expect(tester.getRect(border).right, closeTo(size.width - 24, 0.1));
        expect(
            tester.getRect(find.byIcon(Icons.add)).top -
                tester.getRect(card).top,
            closeTo(24, 1));
        expect(
            tester.getRect(message).top -
                tester.getRect(find.byIcon(Icons.add)).bottom,
            closeTo(8, 1));
        expect(tester.takeException(), isNull);

        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.text('팔로우한 선수'), findsOneWidget);
      });
    }
  }
  testWidgets('favorite editor reuses cards while loading candidate details',
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
    expect(find.text('1touch Ranking'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Look for players'), findsOneWidget);
    final search = tester.widget<Container>(
      find.byKey(const ValueKey('full-ranking-search')),
    );
    expect(
      (search.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(8),
    );
    expect(search.clipBehavior, Clip.antiAlias);
    expect(find.text('Ranked player 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('players scroll returns to the top before leaving the main tab',
      (tester) async {
    await pump(tester, size: const Size(320, 568));
    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView).first,
    );
    final controller = scrollView.controller!;
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));

    mainTabActions.select(3);
    expect(controller.offset, controller.position.minScrollExtent);
    expect(tester.takeException(), isNull);
  });
}

class _PendingCachedRankingRepository extends FakePlayerDirectoryRepository {
  final pending = Completer<PlayerRankingPage>();

  @override
  Future<PlayerRankingPage> ranking({
    int? league,
    String? position,
    int offset = 0,
  }) =>
      pending.future;
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

class _TwoWatchDirectoryRepository extends FakePlayerDirectoryRepository {
  @override
  Future<List<PlayerWatch>> watch() async => [
        (
          id: 1,
          name: 'Improving player',
          image: null,
          jerseyNumber: 17,
          teamId: 7980,
          teamName: 'Atlético de Madrid',
          recent: 8.4,
          previous: 6.2,
          change: 2.2,
        ),
        (
          id: 2,
          name: 'Neymar',
          image: null,
          jerseyNumber: 10,
          teamId: 7980,
          teamName: 'Atlético de Madrid',
          recent: 8.1,
          previous: 7.2,
          change: 0.9,
        ),
      ];
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
