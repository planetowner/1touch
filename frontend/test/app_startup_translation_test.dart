import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lottie/lottie.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/main.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/session_screen.dart';
import 'package:onetouch/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('restores login during the logo and routes to the saved session',
      (tester) async {
    final pending = Completer<http.Response>();
    final restore = Completer<void>();
    final sessionRequest = Completer<http.Response>();
    final requests = <http.Request>[];
    http.runWithClient(
      () => apiClient.baseUri,
      () => MockClient((request) {
        requests.add(request);
        return request.url.path.contains('/football-names/')
            ? pending.future
            : sessionRequest.future;
      }),
    );
    addTearDown(authSession.clear);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(
      () => AssetLottie('assets/animations/onetouch_logo_dark.json').load(),
    );

    await runOneTouchApp(restoreSession: () async {
      await restore.future;
      authSession.establish('startup-test-session');
      return true;
    });
    await tester.pumpAndSettle();
    expect(authSession.isAuthenticated, isFalse);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(requests, isEmpty);
    GoRouter.of(tester.element(find.byType(SplashScreen))).go('/community/123');
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsOneWidget);
    restore.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requests.map((request) => request.url.path),
        ['/v1/football-names/en/display']);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Lottie).hitTestable(), findsOneWidget);
    expect(find.byType(FootballLoadingIndicator), findsNothing);

    pending.complete(http.Response(
        jsonEncode({
          'teams': {},
          'team_short_names': {},
          'players': {},
          'player_short_names': {},
          'competitions': {},
          'countries': {},
          'coaches': {},
        }),
        200));
    await tester.pump();
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Lottie).hitTestable(), findsOneWidget);
    expect(find.byType(FootballLoadingIndicator), findsNothing);
    expect(requests, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
