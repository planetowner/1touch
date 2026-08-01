import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';

void main() {
  testWidgets('opening from Players starts with two neutral player slots',
      (tester) async {
    final router = _comparisonRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open empty comparison'));
    await tester.pumpAndSettle();

    expect(find.text('PLAYER 1'), findsOneWidget);
    expect(find.text('PLAYER 2'), findsOneWidget);

    for (final slot in [1, 2]) {
      final image = tester.widget<Image>(
        find.byKey(Key('comparison-header-photo-$slot')),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/player_comparison/player_placeholder.png',
      );
    }
  });

  testWidgets('back from selection returns to the route that pushed it',
      (tester) async {
    final router = _comparisonRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open comparison'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerComparisonScreen), findsOneWidget);
    expect(find.text('PLAYER 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('Open comparison'), findsOneWidget);
    expect(find.byType(PlayerComparisonScreen), findsNothing);
  });

  testWidgets('back moves from comparison to selection, then to its origin',
      (tester) async {
    final router = _comparisonRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open comparison'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mohamed Salah'));
    await tester.pumpAndSettle();
    expect(find.text('PLAYER 2'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerComparisonScreen), findsOneWidget);
    expect(find.text('PLAYER 2'), findsOneWidget);
    expect(find.text('MOST COMPARED'), findsOneWidget);
    expect(find.text('Open comparison'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    expect(find.text('Open comparison'), findsOneWidget);
  });
}

GoRouter _comparisonRouter() {
  return GoRouter(
    initialLocation: '/player',
    routes: [
      GoRoute(
        path: '/player',
        builder: (context, state) => Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.push('/compare', extra: 'son'),
                child: const Text('Open comparison'),
              ),
              TextButton(
                onPressed: () => context.push('/compare'),
                child: const Text('Open empty comparison'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/compare',
        builder: (context, state) => PlayerComparisonScreen(
          initialPlayerId: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/players',
        builder: (context, state) => const Text('Players fallback'),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SizedBox(),
      ),
    ],
  );
}
