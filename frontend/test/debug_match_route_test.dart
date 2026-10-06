import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/debug/mock_betting_match.dart';
import 'package:onetouch/debug/mock_live_match.dart';
import 'package:onetouch/main.dart';
import 'package:onetouch/screens/MatchScreen.dart';
import 'package:onetouch/session_screen.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/SignComps/sign_in.dart';

void main() {
  testWidgets('debug matches open without account synchronization',
      (tester) async {
    expect(mockBettingMatchEnabled, isTrue);
    expect(mockLiveMatchEnabled, isTrue);
    authSession.clear();
    addTearDown(authSession.clear);

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    final router = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .routerConfig! as GoRouter;
    expect(router.routeInformationProvider.value.uri.path, '/debug/betting');
    expect(find.byType(MatchScreen), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);

    authSession.establish('expired-debug-token');
    router.go('/debug/live-match');
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/debug/live-match');
    expect(find.byType(MatchScreen), findsWidgets);
    expect(find.byType(SessionScreen), findsNothing);

    router.go('/debug/betting');
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/debug/betting');
    expect(find.byType(MatchScreen), findsWidgets);
    expect(find.byType(SessionScreen), findsNothing);

    authSession.clear();
    router.go('/profile');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.routeInformationProvider.value.uri.path, '/onboarding');
    expect(find.byType(OnboardingScreen), findsOneWidget);

    router.go('/auth/signin');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.routeInformationProvider.value.uri.path, '/auth/signin');
    expect(find.byType(EmailSignInScreen), findsOneWidget);
  });
}
