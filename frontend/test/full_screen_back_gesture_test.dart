import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/full_screen_back_gesture.dart';
import 'package:onetouch/core/interactive_back_page.dart';

void main() {
  testWidgets('exposes the iOS back swipe only while dragging', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/detail'),
            child: const Text('Open detail'),
          ),
        ),
      ),
      GoRoute(
        path: '/detail',
        builder: (_, __) => Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('${FullScreenBackGesture.isSwipeActive(context)}'),
            ),
          ),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(_testApp(router));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(find.text('false'), findsOneWidget);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(find.text('true'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('false'), findsOneWidget);

    final cancelled = await tester.startGesture(const Offset(400, 300));
    await cancelled.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(find.text('true'), findsOneWidget);
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(find.text('false'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('right swipe pops a detail at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/detail'),
                child: const Text('Open detail'),
              ),
            ),
          ),
          GoRoute(
            path: '/detail',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Detail'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_testApp(router));
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();

      final start = Offset(size.width / 2, size.height / 2);
      await tester.dragFrom(start, const Offset(-110, 0));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsOneWidget);

      await tester.dragFrom(Offset(24, start.dy), Offset(size.width * 0.6, 0));
      await tester.pumpAndSettle();
      expect(find.text('Open detail'), findsOneWidget);
      expect(
        FullScreenBackGesture.isSwipeActive(
          tester.element(find.text('Open detail')),
        ),
        isFalse,
      );

      await tester.dragFrom(Offset(24, start.dy), Offset(size.width * 0.6, 0));
      await tester.pumpAndSettle();
      expect(find.text('Open detail'), findsOneWidget);
    });
  }

  testWidgets('Navigator.push detail follows the finger before popping',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: _interactiveTheme(),
      builder: (_, child) => FullScreenBackGesture(child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: Center(child: Text('Pushed detail')),
                ),
              ),
            ),
            child: const Text('Open pushed detail'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open pushed detail'));
    await tester.pumpAndSettle();

    final detail = find.text('Pushed detail');
    final initialX = tester.getTopLeft(detail).dx;
    final shortDrag = await tester.startGesture(const Offset(120, 300));
    await shortDrag.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(tester.getTopLeft(detail).dx - initialX, closeTo(80, 1));
    await shortDrag.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(detail).dx, closeTo(initialX, 1));

    final longDrag = await tester.startGesture(const Offset(24, 300));
    await longDrag.moveBy(const Offset(500, 0));
    await longDrag.up();
    await tester.pumpAndSettle();
    expect(detail, findsNothing);
    expect(find.text('Open pushed detail'), findsOneWidget);
  });

  testWidgets('a screen that blocks popping also blocks the swipe',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/form'),
            child: const Text('Open form'),
          ),
        ),
      ),
      GoRoute(
        path: '/form',
        builder: (_, __) => const PopScope(
          canPop: false,
          child: Scaffold(body: Center(child: Text('Unsaved form'))),
        ),
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 300), const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved form'), findsOneWidget);
  });

  testWidgets('Android keeps its system back instead of a full-screen swipe',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/detail'),
            child: const Text('Open detail'),
          ),
        ),
      ),
      GoRoute(
        path: '/detail',
        builder: (_, __) => const Scaffold(body: Center(child: Text('Detail'))),
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      theme: ThemeData(platform: TargetPlatform.android),
      builder: (_, child) => FullScreenBackGesture(child: child!),
      routerConfig: router,
    ));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(400, 300), const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open detail'), findsOneWidget);
  });

  testWidgets('cross-tab detail returns to its own tab root', (tester) async {
    final router = GoRouter(
      initialLocation: '/team',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, _, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: Text('Tab ${shell.currentIndex}'),
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/team',
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => context.go('/players/42'),
                    child: const Text('Open player'),
                  ),
                ),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/players',
                builder: (_, __) => const Scaffold(body: Text('Players root')),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, state) => MaterialPage<void>(
                      key: state.pageKey,
                      child: const Scaffold(
                          body: Center(child: Text('Player 42'))),
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router));
    await tester.tap(find.text('Open player'));
    await tester.pumpAndSettle();
    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('Player 42'), findsOneWidget);

    final route = ModalRoute.of(tester.element(find.text('Player 42')))!;
    expect(route.popGestureEnabled, isTrue);
    final gesture = await tester.startGesture(const Offset(24, 300));
    await gesture.moveBy(const Offset(500, 0));
    await tester.pump();
    expect(route.animation!.value, lessThan(0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Players root'), findsOneWidget);
    expect(find.text('Tab 1'), findsOneWidget);
    expect(find.text('Open player'), findsNothing);
  });

  testWidgets('horizontal child swipe keeps its own gesture', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/detail'),
            child: const Text('Open detail'),
          ),
        ),
      ),
      GoRoute(
        path: '/detail',
        builder: (_, __) => Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 120,
              child: ListView(
                key: const ValueKey('horizontal-list'),
                scrollDirection: Axis.horizontal,
                children: const [
                  SizedBox(width: 500, child: Text('First card')),
                  SizedBox(width: 500, child: Text('Second card')),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(router));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('horizontal-list')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('horizontal-list')), findsOneWidget);
    await tester.drag(
        find.byKey(const ValueKey('horizontal-list')), const Offset(110, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('horizontal-list')), findsOneWidget);
    expect(find.text('Open detail'), findsNothing);
  });
}

Widget _testApp(GoRouter router) => MaterialApp.router(
      theme: _interactiveTheme(),
      builder: (_, child) => FullScreenBackGesture(child: child!),
      routerConfig: router,
    );

ThemeData _interactiveTheme() => ThemeData(
      platform: TargetPlatform.iOS,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: InteractiveBackPageTransitionsBuilder(),
      }),
    );
