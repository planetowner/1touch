import 'dart:async';
import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';
import 'package:onetouch/models/player_detail.dart';
import 'support/player_detail_fixture.dart';

void main() {
  setUpAppCatalog();
  testWidgets(
      'opening the picker sends one page request and no candidate detail requests',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: repository)));
    await tester.pumpAndSettle();
    repository.calls.clear();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);
    expect(repository.comparisonQueries,
        [(query: '', position: 'FW', excludedId: 1, limit: 20, offset: 0)]);
    expect(find.text('Player 2'), findsNothing);
    expect(find.text('Player 3'), findsOneWidget);
    await tester.tap(find.text('Player 3'));
    await tester.pumpAndSettle();
    expect(repository.calls, [(playerId: 3, seasonId: null)]);
    expect(find.byKey(const ValueKey('comparison-season-picker-sheet')),
        findsOneWidget);
    await tester.tap(find.text('26/27'));
    await tester.pumpAndSettle();
    expect(repository.calls, [(playerId: 3, seasonId: null)]);
    expect(find.byKey(const ValueKey('comparison-stat-card-Finish')),
        findsOneWidget);
  });

  testWidgets('a different season is fetched and its position is checked again',
      (tester) async {
    final repository = _SeasonPositionRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25/26'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (playerId: 3, seasonId: 25651));
    expect(find.text('Select a player with the same season position (FW).'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-stat-card-Finish')),
        findsNothing);
  });

  testWidgets(
      'loads the next page and retries at the same offset without preloading details',
      (tester) async {
    final repository = _PagedRepository()..failNextPage = true;
    await tester.pumpWidget(
        MaterialApp(home: PlayerComparisonScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 1'));
    await tester.pumpAndSettle();
    final list = find.descendant(
        of: find.byKey(const ValueKey('comparison-player-picker-sheet')),
        matching: find.byType(ListView));
    final more = find.byKey(const ValueKey('comparison-load-more'));
    await tester.dragUntilVisible(more, list, const Offset(0, -400));
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(repository.pageOffsets, [0, 20]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.pageOffsets, [0, 20, 20]);
    await tester.dragUntilVisible(
        find.text('Player 21'), list, const Offset(0, -100));
    expect(find.text('Player 21'), findsOneWidget);
    expect(repository.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('failed selection stays visible and retries at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakePlayerDetailRepository();
      await tester.pumpWidget(MaterialApp(
          home: PlayerComparisonScreen(
              initialPlayerId: '1', repository: repository)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PLAYER 2'));
      await tester.pumpAndSettle();
      repository.fail = true;
      await tester.tap(find.text('Player 3'));
      await tester.pumpAndSettle();
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('No players found'), findsNothing);
      expect(
          find.text(
              'Could not load player data. Please select the player again.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      repository.fail = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('comparison-season-picker-sheet')),
          findsOneWidget);
      expect(repository.calls.where((call) => call.playerId == 3).length, 2);
    });
  }

  testWidgets('late first and next page responses never replace a newer search',
      (tester) async {
    final repository = _PendingComparisonRepository();
    await tester.pumpWidget(
        MaterialApp(home: PlayerComparisonScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final field = find.byKey(const ValueKey('comparison-player-search-field'));
    await tester.enterText(field, 'old');
    await tester.pump(const Duration(milliseconds: 300));
    repository.pending[('old', 0)]!.complete(_page(1, total: 2));
    await tester.pumpAndSettle();
    repository.pending[('', 0)]!.complete(_page(99));
    await tester.pumpAndSettle();
    expect(find.text('Player 99'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('comparison-load-more')));
    await tester.pump();
    await tester.enterText(field, 'new');
    await tester.pump(const Duration(milliseconds: 300));
    repository.pending[('new', 0)]!.complete(_page(7));
    await tester.pumpAndSettle();
    repository.pending[('old', 1)]!.complete(_page(2, offset: 1, total: 2));
    await tester.pumpAndSettle();
    expect(find.text('Player 7'), findsOneWidget);
    expect(find.text('Player 1'), findsNothing);
    expect(find.text('Player 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial page errors show retry and recover', (tester) async {
    final repository = _PendingComparisonRepository();
    await tester.pumpWidget(
        MaterialApp(home: PlayerComparisonScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 1'));
    await tester.pump();
    repository.pending[('', 0)]!.completeError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No players found'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    repository.pending[('', 0)]!.complete(_page(3));
    await tester.pumpAndSettle();
    expect(find.text('Player 3'), findsOneWidget);
  });

  testWidgets(
      'closing a pending selection does not close the comparison screen',
      (tester) async {
    final repository = _PendingSelectionRepository();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => PlayerComparisonScreen(
                                initialPlayerId: '1', repository: repository),
                          )),
                      child: const Text('Open comparison')),
                ))));
    await tester.tap(find.text('Open comparison'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 3'));
    await tester.pump();
    await tester.tap(find.text('Player 3'));
    expect(repository.selections, 1);
    await tester.tap(find.byIcon(Icons.close));
    repository.pending.complete(detailFixture(playerId: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-comparison-scaffold')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-season-picker-sheet')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty comparison has two empty slots', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home:
            PlayerComparisonScreen(repository: FakePlayerDetailRepository())));
    await tester.pumpAndSettle();
    expect(find.text('PLAYER 1'), findsOneWidget);
    expect(find.text('PLAYER 2'), findsOneWidget);
    expect(find.text('MOST COMPARED'), findsOneWidget);
  });
  testWidgets('back clears comparison before returning to origin',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    final router = GoRouter(initialLocation: '/origin', routes: [
      GoRoute(
          path: '/origin',
          builder: (context, _) => Scaffold(
              body: TextButton(
                  onPressed: () => context.push('/compare'),
                  child: const Text('Open comparison')))),
      GoRoute(
          path: '/compare',
          builder: (_, __) => PlayerComparisonScreen(
              initialPlayerId: '1', repository: repository)),
      GoRoute(path: '/players', builder: (_, __) => const Text('Players')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open comparison'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('26/27'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.text('PLAYER 2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.text('Open comparison'), findsOneWidget);
  });

  testWidgets('selected player chip reloads the chosen API season',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Player 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('25/26'));
    await tester.pumpAndSettle();

    expect(repository.calls.last, (playerId: 1, seasonId: 25651));
  });

  testWidgets('player search updates automatically after typing',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();

    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('comparison-player-search-field')),
    );
    final searchBorder = searchField.decoration!.border! as OutlineInputBorder;
    expect(searchBorder.borderRadius, BorderRadius.circular(8));

    await tester.enterText(
      find.byKey(const ValueKey('comparison-player-search-field')),
      'missing',
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.searchQueries, ['']);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(repository.searchQueries.last, 'missing');
    expect(find.text('No players found'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('comparison-player-search-field')),
      'Player 3',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.searchQueries.last, 'Player 3');
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Player 3',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _PagedRepository extends FakePlayerDetailRepository {
  bool failNextPage = false;
  final pageOffsets = <int>[];

  @override
  Future<List<PlayerCandidate>> search(String query) async => [
        for (var id = 1; id <= 41; id++)
          (id: id, name: 'Player $id', image: null),
      ];

  @override
  Future<PlayerComparisonPage> comparisonCandidates(String query,
      {String? position, int? excludedId, int limit = 20, int offset = 0}) {
    pageOffsets.add(offset);
    if (offset > 0 && failNextPage) {
      failNextPage = false;
      return Future.error(StateError('Next page unavailable'));
    }
    return super.comparisonCandidates(query,
        position: position,
        excludedId: excludedId,
        limit: limit,
        offset: offset);
  }
}

class _SeasonPositionRepository extends FakePlayerDetailRepository {
  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async {
    calls.add((playerId: playerId, seasonId: seasonId));
    return detailFixture(
        playerId: playerId,
        seasonId: seasonId,
        position: playerId == 3 && seasonId == 25651 ? 'MF' : 'FW');
  }
}

class _PendingSelectionRepository extends FakePlayerDetailRepository {
  final pending = Completer<PlayerDetail>();
  int selections = 0;

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) {
    if (playerId != 3) return super.load(playerId, seasonId: seasonId);
    selections++;
    return pending.future;
  }
}

class _PendingComparisonRepository extends FakePlayerDetailRepository {
  final pending = <(String, int), Completer<PlayerComparisonPage>>{};

  @override
  Future<PlayerComparisonPage> comparisonCandidates(String query,
      {String? position, int? excludedId, int limit = 20, int offset = 0}) {
    final result = Completer<PlayerComparisonPage>();
    pending[(query, offset)] = result;
    return result.future;
  }
}

PlayerComparisonPage _page(int id, {int offset = 0, int? total}) =>
    PlayerComparisonPage(
      players: [
        PlayerComparisonCandidate(
          player: (id: id, name: 'Player $id', image: null),
          position: 'FW',
          teamId: null,
          teamName: null,
          jerseyNumber: null,
        )
      ],
      seasonName: '2026/2027',
      total: total ?? 1,
      limit: 20,
      offset: offset,
    );
