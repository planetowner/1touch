import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  setUpAppCatalog();
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

  testWidgets('updates stage and leg labels when the app language changes',
      (tester) async {
    const cupFixture = Fixture(
      fixtureId: 2,
      seasonId: 1,
      competitionId: 2,
      homeTeamId: 8,
      awayTeamId: 19,
      competitionType: CompetitionType.europe,
      roundName: null,
      stageName: 'Semi-finals',
      leg: '2/2',
      status: FixtureStatus.upcoming,
      startingAt: null,
    );
    for (final entry in {
      'en': 'UCL · Semi-final · Leg 2 of 2',
      'ko': 'UEFA 챔피언스리그 준결승 2차전',
      'ja': 'Champions League  Semi-finals • 第2戦',
      'zh': 'Champions League  Semi-finals • 第2回合',
    }.entries) {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(entry.key),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: FootballNamesScope(
          names: FootballNames(
              competitions:
                  entry.key == 'ko' ? const {2: 'UEFA 챔피언스리그'} : const {}),
          child: const Scaffold(
            body: MatchCard(match: cupFixture, leagueName: 'Champions League'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

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
