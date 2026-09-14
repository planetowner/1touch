import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/screens/TeamScreen.dart';

import 'support/test_team_overview_repository.dart';

void main() {
  testWidgets('Team shows an explicit missing-team state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: TeamScreen(
          teamId: -1,
          teamOverviewRepository: TestTeamOverviewRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('team-load-error')), findsOneWidget);
    expect(find.text('Unable to load team'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Team displays loading data and retries a failed request',
      (tester) async {
    final firstRequest = Completer<void>();
    var attempts = 0;
    final repository = TestTeamOverviewRepository(
      loader: (teamId) async {
        attempts++;
        if (attempts == 1) {
          await firstRequest.future;
          throw StateError('Test failure');
        }
        return testTeamOverview(teamId: teamId);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: TeamScreen(
          teamId: 9,
          teamOverviewRepository: repository,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    firstRequest.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('team-load-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Manchester City'), findsWidgets);
    expect(repository.requestedTeamIds, [9, 9]);
  });
}
