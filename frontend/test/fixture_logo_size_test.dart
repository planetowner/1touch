import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/fixture.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  for (final width in [320.0, 430.0]) {
    testWidgets('fixture logos stay fixed at ${width.toInt()}px screen width',
        (tester) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  MatchCard(
                    match: Fixture(
                      fixtureId: 1,
                      seasonId: 1,
                      competitionId: 8,
                      homeTeamId: 8,
                      awayTeamId: 19,
                      homeTeamLogo: 'https://example.test/home.png',
                      awayTeamLogo: 'https://example.test/away.png',
                      competitionType: CompetitionType.league,
                      roundName: '1',
                      status: FixtureStatus.upcoming,
                      startingAt: '2026-10-01T18:00:00Z',
                    ),
                  ),
                  MatchCard2(
                    date: '6 days ago',
                    venue: '',
                    team1shortname: 'AAA',
                    team1Logo: 'https://example.test/home.png',
                    team1Id: 8,
                    team2shortname: 'BBB',
                    team2Logo: 'https://example.test/away.png',
                    team2Id: 19,
                    homeScore: 2,
                    awayScore: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      for (final key in ['next-match-home-logo', 'next-match-away-logo']) {
        expect(tester.getSize(find.byKey(ValueKey(key))), const Size(72, 72));
      }
      for (final key in ['last-match-home-logo', 'last-match-away-logo']) {
        expect(tester.getSize(find.byKey(ValueKey(key))), const Size(48, 48));
      }
      expect(
        tester
                .getTopLeft(
                  find.byKey(const ValueKey('last-match-home-score')),
                )
                .dx -
            tester
                .getTopRight(
                  find.byKey(const ValueKey('last-match-home-logo')),
                )
                .dx,
        16,
      );
      expect(
        tester
                .getTopLeft(
                  find.byKey(const ValueKey('last-match-away-logo')),
                )
                .dx -
            tester
                .getTopRight(
                  find.byKey(const ValueKey('last-match-away-score')),
                )
                .dx,
        16,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
