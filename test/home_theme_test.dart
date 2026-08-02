import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/HomeScreenFeatures.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  const match = Fixture(
    fixtureId: 1,
    seasonId: 1,
    leagueId: 8,
    homeTeamId: 8,
    awayTeamId: 19,
    competitionType: CompetitionType.league,
    roundName: 'Round 1',
    status: FixtureStatus.upcoming,
    startingAt: '2026-08-10 12:00:00',
  );

  for (final testCase in <({String name, ThemeData theme})>[
    (name: 'dark', theme: app_style.darktheme),
    (name: 'light', theme: app_style.whitetheme),
  ]) {
    testWidgets('Home surfaces follow the ${testCase.name} theme',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: const [
                  SyncDialog(),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: MatchCard(
                      match: match,
                      leagueName: 'Premier League',
                    ),
                  ),
                  FixtureCalendar(allMatches: [], favoriteTeamId: 8),
                ],
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(Scaffold));
      final semanticColors = app_style.AppColors.of(context);
      final colorScheme = Theme.of(context).colorScheme;

      expect(tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
          semanticColors.cardBackground);

      final matchSurface = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(MatchCard),
            matching: find.byType(Container),
          ))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .first;
      expect(matchSurface.color, semanticColors.subtleBackground);

      final calendarSurface = tester
          .widgetList<Container>(find.descendant(
            of: find.byType(FixtureCalendar),
            matching: find.byType(Container),
          ))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (decoration) =>
                decoration.borderRadius == BorderRadius.circular(28),
          );
      expect(calendarSurface.color, semanticColors.cardBackground);

      final todayText = tester.widget<Text>(find.text('${DateTime.now().day}'));
      expect(todayText.style?.color, colorScheme.onPrimary);
      expect(tester.takeException(), isNull);
    });
  }
}
