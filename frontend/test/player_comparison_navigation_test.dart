import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';
import 'support/player_detail_fixture.dart';

void main() {
  setUpAppCatalog();
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
}
