import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/screens/TeamScreen.dart';

void main() {
  testWidgets('Team shows an explicit missing-team state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: TeamScreen(
          teamId: -1,
          teamRepository: MockTeamRepository(teams: const []),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('team-not-found')), findsOneWidget);
    expect(find.text('Team Not Found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
