import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/Splash.dart';
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/main.dart';
import 'package:onetouch/screens/HomeScreen.dart';

void main() {
  testWidgets('routes from splash using the configured onboarding mode',
      (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    if (ApiConfig.skipOnboardingForDevelopment) {
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    } else {
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    }
  });

  testWidgets('skip-onboarding flow still shows the startup splash',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(
            nextLocation: '/home',
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Text('Development Home'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Development Home'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Development Home'), findsOneWidget);
  });
}
