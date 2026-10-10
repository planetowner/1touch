import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/notification_navigation.dart';

void main() {
  test('accepts only supported in-app notification routes', () {
    expect(isSupportedDestination('/match/42?status=live'), isTrue);
    expect(isSupportedDestination('/notifications/post/91'), isTrue);
    expect(isSupportedDestination('https://example.com/match/42'), isFalse);
    expect(isSupportedDestination('/match/42?status=invalid'), isFalse);
    expect(isSupportedDestination('/profile/edit'), isFalse);
  });

  test('pending destination belongs to the session that received it', () {
    final navigation = NotificationNavigation();
    navigation.queue('/notifications/post/91', sessionToken: 'first-session');

    expect(navigation.take(sessionToken: 'second-session'), isNull);
    expect(navigation.take(sessionToken: 'first-session'), isNull);
  });

  for (final destination in [
    '/match/42?status=live',
    '/notifications/post/91'
  ]) {
    for (final startup in [
      (path: '/', ready: true),
      (path: '/session', ready: true),
      (path: '/profile', ready: false),
    ]) {
      testWidgets('$destination waits for the session at ${startup.path}',
          (tester) async {
        final navigation = NotificationNavigation();
        final router = _router(startup.path);
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));

        navigation.open(
          destination,
          router: router,
          sessionToken: 'current-account',
          isSessionReady: startup.ready,
        );
        await tester.pumpAndSettle();

        expect(find.text(startup.path), findsOneWidget);
        expect(router.canPop(), isFalse);
        expect(navigation.take(sessionToken: 'current-account'), destination);
        expect(navigation.take(sessionToken: 'current-account'), isNull);
      });
    }
  }

  for (final input in [
    (destination: '/match/42', token: null),
    (destination: 'https://example.com/match/42', token: 'current-account'),
  ]) {
    testWidgets(
        'does not open or queue an unauthenticated or invalid input $input',
        (tester) async {
      final navigation = NotificationNavigation();
      final router = _router('/profile');
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      navigation.open(
        input.destination,
        router: router,
        sessionToken: input.token,
        isSessionReady: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('/profile'), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(navigation.take(sessionToken: 'current-account'), isNull);
    });
  }
}

GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        for (final path in [
          '/',
          '/session',
          '/profile',
          '/match/:id',
          '/notifications/post/:id'
        ])
          GoRoute(
            path: path,
            builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
          ),
      ],
    );
