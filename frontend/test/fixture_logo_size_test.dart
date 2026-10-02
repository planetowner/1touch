import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/fixture.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
  });

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
                    date: 'Last week',
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
      final lastWeek = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('last-match-date-time')),
        matching: find.text('Last week'),
      ));
      expect(lastWeek.maxLines, 1);
      expect(lastWeek.softWrap, isFalse);
      expect(lastWeek.overflow, TextOverflow.visible);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('last-match-date-time')),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      final surface =
          tester.getRect(find.byKey(const ValueKey('last-match-card-surface')));
      final homeLogo =
          tester.getRect(find.byKey(const ValueKey('last-match-home-logo')));
      final homeScore =
          tester.getRect(find.byKey(const ValueKey('last-match-home-score')));
      final date =
          tester.getRect(find.byKey(const ValueKey('last-match-date-time')));
      final awayScore =
          tester.getRect(find.byKey(const ValueKey('last-match-away-score')));
      final awayLogo =
          tester.getRect(find.byKey(const ValueKey('last-match-away-logo')));
      expect(homeLogo.left - surface.left, 16);
      expect(surface.right - awayLogo.right, 16);
      final gaps = [
        homeScore.left - homeLogo.right,
        date.left - homeScore.right,
        awayScore.left - date.right,
        awayLogo.left - awayScore.right,
      ];
      expect(gaps.every((gap) => gap >= 4 && gap <= 16), isTrue);
      expect(gaps.every((gap) => (gap - gaps.first).abs() < 0.1), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long last-match date scrolls between fixed scores',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MatchCard2(
          date: '2 weeks ago in extra time',
          venue: '',
          team1shortname: 'FCB',
          team1Logo: '',
          team1Id: 8,
          team2shortname: 'FCU',
          team2Logo: '',
          team2Id: 19,
          homeScore: 7,
          awayScore: 0,
        ),
      ),
    ));

    final date = find.byKey(const ValueKey('last-match-date-time'));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: date, matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(find.descendant(
            of: date, matching: find.text('2 weeks ago in extra time')),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(scrollable.position.pixels, greaterThan(0));
    final dateRect = tester.getRect(date);
    expect(
        dateRect.left,
        greaterThan(tester
            .getRect(find.byKey(const ValueKey('last-match-home-score')))
            .right));
    expect(
        dateRect.right,
        lessThan(tester
            .getRect(find.byKey(const ValueKey('last-match-away-score')))
            .left));
    expect(tester.takeException(), isNull);
  });
}
