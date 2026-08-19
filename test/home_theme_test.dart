import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/HomeScreenFeatures.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_overview.dart';

void main() {
  const match = Fixture(
    fixtureId: 1,
    seasonId: 1,
    competitionId: 8,
    homeTeamId: 8,
    awayTeamId: 19,
    competitionType: CompetitionType.league,
    roundName: 'Round 1',
    status: FixtureStatus.upcoming,
    startingAt: '2026-08-10 12:00:00',
  );

  const lastMatch = Fixture(
    fixtureId: 2,
    seasonId: 1,
    competitionId: 8,
    homeTeamId: 8,
    awayTeamId: 6,
    competitionType: CompetitionType.league,
    roundName: 'Round 2',
    status: FixtureStatus.past,
    startingAt: '2026-08-03 12:00:00',
    homeScore: 3,
    awayScore: 0,
  );

  const liveMatch = Fixture(
    fixtureId: 3,
    seasonId: 1,
    competitionId: 8,
    homeTeamId: 8,
    awayTeamId: 19,
    competitionType: CompetitionType.league,
    roundName: 'Round 3',
    status: FixtureStatus.live,
    startingAt: '2026-08-18 12:00:00',
    homeScore: 1,
    awayScore: 1,
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

  for (final testCase in <({
    String name,
    ThemeData theme,
    Color outer,
    Color next,
    Color last,
  })>[
    (
      name: 'dark',
      theme: app_style.darktheme,
      outer: app_style.AppPalette.darkGrey,
      next: app_style.AppPalette.lightGrey,
      last: app_style.AppPalette.darkGrey,
    ),
    (
      name: 'light',
      theme: app_style.whitetheme,
      outer: app_style.AppPalette.white,
      next: app_style.AppPalette.lightGreyBox,
      last: app_style.AppPalette.white,
    ),
  ]) {
    testWidgets('Favorite team match sections use ${testCase.name} surfaces',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FavoriteTeamCard(
                team: TeamOverview(
                  id: 8,
                  name: 'Liverpool',
                  shortName: 'LIV',
                  imagePath: 'https://example.com/liverpool.png',
                  nextMatch: match,
                  lastMatch: lastMatch,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      Color surfaceColor(String key) {
        final container = tester.widget<Container>(
          find.byKey(ValueKey(key)),
        );
        return (container.decoration as BoxDecoration).color!;
      }

      final nextFinder = find.byKey(const ValueKey('match-card-surface'));
      final lastFinder = find.byKey(const ValueKey('last-match-card-surface'));

      expect(surfaceColor('home-favorite-team-surface'), testCase.outer);
      expect(surfaceColor('match-card-surface'), testCase.next);
      expect(surfaceColor('last-match-card-surface'), testCase.last);
      expect(find.text('NEXT MATCH'), findsOneWidget);
      expect(find.text('LIVE MATCH'), findsNothing);
      expect(
        tester.getBottomLeft(nextFinder).dy,
        closeTo(tester.getTopLeft(lastFinder).dy, 0.1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Favorite team prioritizes a live match over the next match',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FavoriteTeamCard(
              team: TeamOverview(
                id: 8,
                name: 'Liverpool',
                shortName: 'LIV',
                imagePath: 'https://example.com/liverpool.png',
                liveMatch: liveMatch,
                nextMatch: match,
                lastMatch: lastMatch,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final displayedMatch = tester.widget<MatchCard>(find.byType(MatchCard));
    expect(displayedMatch.match?.fixtureId, liveMatch.fixtureId);
    expect(find.text('LIVE MATCH'), findsOneWidget);
    expect(find.text('NEXT MATCH'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
