import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:onetouch/splash.dart';

Future<void> _pumpSplash(
  WidgetTester tester,
  Future<String> Function() prepare,
) async {
  await tester.runAsync(
    () => AssetLottie('assets/animations/onetouch_logo_dark.json').load(),
  );
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => SplashScreen(prepareNextLocation: prepare),
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const Scaffold(body: Text('Ready Home')),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    theme: ThemeData.dark(),
    routerConfig: router,
  ));
  await tester.pump();
}

void main() {
  for (final prepareEarly in [true, false]) {
    testWidgets('waits for logo and initialization (early: $prepareEarly)',
        (tester) async {
      final pending = Completer<String>();
      var calls = 0;
      await _pumpSplash(tester, () {
        calls++;
        expect(find.byType(SplashScreen), findsOneWidget);
        return pending.future;
      });
      final state = tester.state(find.byType(SplashScreen));
      expect(calls, 1);
      expect(find.byType(Lottie).hitTestable(), findsOneWidget);
      if (prepareEarly) {
        pending.complete('/home');
        await tester.pump();
        expect(find.text('Ready Home'), findsNothing);
      }

      await tester.pump(const Duration(seconds: 3));
      if (!prepareEarly) {
        // 초기화가 로고보다 늦어도 완성된 로고가 사라지지 않아요.
        final animation =
            tester.widget<Lottie>(find.byType(Lottie)).controller!;
        expect(animation.value, 0.5);
        await tester.pump(const Duration(seconds: 5));
        expect(animation.value, 0.5);
        expect(find.text('Ready Home'), findsNothing);
        expect(tester.state(find.byType(SplashScreen)), same(state));
        pending.complete('/home');
      }
      await tester.pumpAndSettle();
      expect(find.text('Ready Home'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('initialization failure can retry without skipping preparation',
      (tester) async {
    var calls = 0;
    await _pumpSplash(tester, () async {
      if (++calls == 1) throw StateError('Initialization unavailable');
      return '/home';
    });
    await tester.pumpAndSettle();
    expect(find.text('Ready Home'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-error-500-action')));
    await tester.pumpAndSettle();
    expect(find.text('Ready Home'), findsOneWidget);
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing initialization after disposal does not navigate',
      (tester) async {
    final pending = Completer<String>();
    await _pumpSplash(tester, () => pending.future);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete('/home');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
