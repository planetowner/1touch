import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  testWidgets('headers and team lists follow language changes together',
      (tester) async {
    for (final (language, league, expected) in [
      ('en', 'Premier League', 'Premier League 2nd'),
      ('ko', '프리미어리그', '프리미어리그 2위'),
      ('ja', 'プレミアリーグ', 'プレミアリーグ 2位'),
      ('zh', '英超联赛', '英超联赛 第2名'),
      ('en', 'Premier League', 'Premier League 2nd'),
    ]) {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: FootballNamesScope(
          names: FootballNames(competitions: {8: league}),
          child: Builder(builder: (context) {
            final name = competitionNameLabel(context, 8, 'Premier League');
            return Column(children: [
              Text(leaguePositionLabel(context, name, 2)),
              Text(teamCompetitionLabel(
                  context,
                  const TeamCompetitionContext(
                    teamId: 9,
                    competitionId: 8,
                    competitionName: 'Premier League',
                    currentPosition: 2,
                  ))),
            ]);
          }),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('team lists use correct English rank suffixes', (tester) async {
    const ranks = {
      1: '1st',
      2: '2nd',
      3: '3rd',
      4: '4th',
      11: '11th',
      12: '12th',
      13: '13th',
      21: '21st',
      22: '22nd',
      23: '23rd',
      24: '24th',
    };
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Column(children: [
                for (final position in ranks.keys)
                  Text(teamCompetitionLabel(
                      context,
                      TeamCompetitionContext(
                        teamId: 9,
                        competitionName: 'League',
                        currentPosition: position,
                      ))),
              ])),
    ));
    for (final rank in ranks.values) {
      expect(find.text('League $rank'), findsOneWidget);
    }
  });

  testWidgets('missing ranks retain each surface’s empty-state label',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        expect(leaguePositionLabel(context, 'League', null), 'League -');
        expect(
            leaguePositionLabel(context, 'League', null,
                missingPositionLabel: null),
            'League');
        expect(
            teamCompetitionLabel(
                context,
                const TeamCompetitionContext(
                  teamId: 9,
                  competitionName: 'League',
                )),
            'League');
        expect(teamCompetitionLabel(context, null), isEmpty);
        expect(
            teamCompetitionLabel(context,
                const TeamCompetitionContext(teamId: 9, currentPosition: 2)),
            isEmpty);
        return const SizedBox.shrink();
      }),
    ));
  });
}
