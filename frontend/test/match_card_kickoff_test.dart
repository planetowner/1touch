import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  const fixture = Fixture(
    fixtureId: 1,
    seasonId: 1,
    competitionId: 8,
    homeTeamId: 8,
    awayTeamId: 19,
    competitionType: CompetitionType.league,
    roundName: null,
    status: FixtureStatus.upcoming,
    startingAt: null,
  );

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
        'shows an undated fixture safely at ${size.width}x${size.height}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MatchCard(
              match: fixture,
              leagueName: 'Premier League',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Date TBD'), findsOneWidget);
      expect(find.text('Premier League'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
