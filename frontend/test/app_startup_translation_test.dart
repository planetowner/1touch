import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lottie/lottie.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/main.dart';
import 'package:onetouch/splash.dart';

void main() {
  testWidgets('startup logo remains visible while translations load',
      (tester) async {
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    http.runWithClient(
      () => apiClient.baseUri,
      () => MockClient((request) {
        requests.add(request);
        return pending.future;
      }),
    );
    authSession.establish('startup-test-session');
    addTearDown(authSession.clear);
    await tester.runAsync(
      () => AssetLottie('assets/animations/onetouch_logo_dark.json').load(),
    );

    await tester.pumpWidget(const MyApp());
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
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
