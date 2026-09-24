import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/HomeScreenFeatures.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';

const competitions = {
  8: Competition(competitionId: 8, name: 'Premier League', shortCode: 'PL'),
  564: Competition(competitionId: 564, name: 'La Liga', shortCode: 'LALIGA'),
  2: Competition(competitionId: 2, name: 'Champions League', shortCode: 'UCL'),
  5: Competition(competitionId: 5, name: 'Europa League', shortCode: 'UEL'),
  2286: Competition(
      competitionId: 2286, name: 'Conference League', shortCode: 'UECL'),
  24: Competition(competitionId: 24, name: 'FA Cup', shortCode: 'FA Cup'),
  27: Competition(competitionId: 27, name: 'Carabao Cup', shortCode: 'EFL Cup'),
  570: Competition(competitionId: 570, name: 'Copa Del Rey', shortCode: 'CDR'),
};

HomeCalendarFixture match(int competitionId, DateTime kickoff) =>
    HomeCalendarFixture(
      fixture: Fixture(
        fixtureId: competitionId,
        seasonId: 1,
        competitionId: competitionId,
        homeTeamId: 8,
        awayTeamId: 19,
        competitionType: switch (competitionId) {
          8 || 564 => CompetitionType.league,
          2 || 5 || 2286 => CompetitionType.europe,
          _ => CompetitionType.cup,
        },
        roundName: null,
        status: FixtureStatus.upcoming,
        startingAt: kickoff.toIso8601String(),
      ),
      opponent: const Team(teamId: 19, name: 'Opponent'),
    );

Widget calendar(
        List<int> ids, List<HomeCalendarFixture> matches, Locale locale) =>
    MaterialApp(
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Scaffold(
          body: SingleChildScrollView(
              child: FixtureCalendar(
        favoriteTeamId: 8,
        participatingCompetitions: [for (final id in ids) competitions[id]!],
        allMatches: matches,
      ))),
    );

void expectLegend(WidgetTester tester, Map<String, Color> expected) {
  final legend = find.byKey(const ValueKey('fixture-calendar-legends'));
  if (expected.isEmpty) {
    expect(legend, findsNothing);
    return;
  }
  expect(
      tester
          .widgetList<Text>(
              find.descendant(of: legend, matching: find.byType(Text)))
          .map((text) => text.data),
      expected.keys);
  for (final entry in expected.entries) {
    final dot = tester.widget<Container>(find.descendant(
      of: find.byKey(ValueKey('calendar-legend-${entry.key}')),
      matching: find.byType(Container),
    ));
    expect((dot.decoration as BoxDecoration).color, entry.value);
  }
}

void main() {
  for (final locale in appSupportedLocales) {
    for (final scenario
        in <({String name, List<int> ids, Map<String, Color> colors})>[
      (
        name: 'UEL and Copa',
        ids: [570, 564, 5],
        colors: {'UEL': Colors.red, 'CDR': Colors.blue}
      ),
      (
        name: 'UCL and two English cups',
        ids: [27, 24, 8, 2],
        colors: {
          'UCL': Colors.red,
          'FA Cup': Colors.blue,
          'EFL Cup': Colors.green
        }
      ),
      (name: 'only Carabao', ids: [27, 8], colors: {'EFL Cup': Colors.red}),
      (
        name: 'two English cups',
        ids: [27, 8, 24],
        colors: {'FA Cup': Colors.red, 'EFL Cup': Colors.blue}
      ),
      (
        name: 'UECL and Copa',
        ids: [570, 2286, 564],
        colors: {'UECL': Colors.red, 'CDR': Colors.blue}
      ),
      (name: 'league only', ids: [8], colors: {}),
    ]) {
      testWidgets(
          '${scenario.name} uses participation priority in ${locale.languageCode}',
          (tester) async {
        final now = DateTime.now();
        await tester.pumpWidget(calendar(
            scenario.ids,
            [
              for (var i = 0; i < scenario.ids.length; i++)
                match(scenario.ids[i], DateTime(now.year, now.month, 10 + i)),
            ],
            locale));
        await tester.pump();
        expectLegend(tester, scenario.colors);
        for (final id in scenario.ids) {
          final dot = find.byKey(ValueKey('calendar-fixture-dot-$id'));
          final color = scenario.colors[competitions[id]!.shortCode];
          if (color == null) {
            expect(dot, findsNothing);
          } else {
            expect(
                (tester.widget<Container>(dot).decoration as BoxDecoration)
                    .color,
                color);
          }
        }
        expect(
            find.byWidgetPredicate(
                (widget) => widget is Image && widget.image is NetworkImage),
            findsNWidgets(scenario.ids.length));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'month changes keep colors even when the European competition has no fixture',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(calendar([
      8,
      24,
      2
    ], [
      match(24, DateTime(now.year, now.month + 1, 15)),
    ], const Locale('en')));
    expectLegend(tester, {'UCL': Colors.red, 'FA Cup': Colors.blue});
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expectLegend(tester, {'UCL': Colors.red, 'FA Cup': Colors.blue});
    final dot = tester.widget<Container>(
        find.byKey(const ValueKey('calendar-fixture-dot-24')));
    expect((dot.decoration as BoxDecoration).color, Colors.blue);

    // 홈에서 조회 팀을 바꾸면 새 참가 목록을 기준으로 다시 배정해요.
    await tester.pumpWidget(calendar([8, 27], [], const Locale('en')));
    expectLegend(tester, {'EFL Cup': Colors.red});
    expect(tester.takeException(), isNull);
  });
}
