import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/features/team/attributes/match_attribute_comparison.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Analysis.dart';

void main() {
  testWidgets('preview and team page render the same current attribute values',
      (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(AttributesSection(
      team: const {'id': 83},
      repository: repository,
    )));
    await tester.pumpAndSettle();
    final teamValues = tester
        .widget<RadarChart>(find.byType(RadarChart))
        .data
        .dataSets
        .first
        .dataEntries
        .map((entry) => entry.value)
        .toList();

    await tester.pumpWidget(_app(_comparison(repository)));
    await tester.pumpAndSettle();
    final chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(
        chart.data.dataSets.first.dataEntries.map((e) => e.value), teamValues);
    expect(chart.data.dataSets[1].dataEntries.map((e) => e.value),
        _scores(19).radarValues);
    expect(chart.data.dataSets.last.dataEntries.map((e) => e.value),
        [0, 100, 100, 100, 100]);
    expect(repository.requests, [(83, 27965), (83, 27965), (19, 27965)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'keeps the section with the preparing message when data is absent',
      (tester) async {
    final repository = _Repository()..missing = true;
    await tester.pumpWidget(_app(_comparison(repository)));
    await tester.pumpAndSettle();
    expect(find.text('ATTRIBUTES'), findsOneWidget);
    expect(find.text('아직 준비중이에요ㅠㅠ'), findsOneWidget);
    expect(find.byType(RadarChart), findsNothing);
  });

  testWidgets('retries failed attribute requests without displaying mock data',
      (tester) async {
    final repository = _Repository()..fail = true;
    await tester.pumpWidget(_app(_comparison(repository)));
    await tester.pumpAndSettle();
    expect(find.byType(RadarChart), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('능력치를 불러오지 못했어요. 다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(RadarChart), findsOneWidget);
  });

  testWidgets('ignores previous team data after switching the match',
      (tester) async {
    final pending = Completer<List<TeamAttributeScores>>();
    final repository = _Repository()..pending = pending;
    await tester.pumpWidget(_app(_comparison(repository)));
    await tester.pump();
    await tester.pumpWidget(_app(_comparison(repository, homeTeamId: 8)));
    await tester.pumpAndSettle();
    pending.complete([_scores(83)]);
    await tester.pumpAndSettle();
    final chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(chart.data.dataSets.first.dataEntries.map((e) => e.value),
        _scores(8).radarValues);
  });
}

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Widget _comparison(_Repository repository, {int homeTeamId = 83}) =>
    MatchAttributeComparison(
      homeTeamId: homeTeamId,
      awayTeamId: 19,
      homeTeamName: 'Home',
      awayTeamName: 'Away',
      repository: repository,
    );

TeamAttributeScores _scores(int teamId) => TeamAttributeScores(
      teamId: teamId,
      competitionId: 564,
      seasonId: 27965,
      seasonLabel: '2026/2027',
      attack: teamId.toDouble(),
      progression: 54,
      dominance: 63,
      defense: 72,
      possession: 81,
    );

class _Repository implements TeamAttributeRepository {
  final requests = <(int, int?)>[];
  bool missing = false;
  bool fail = false;
  Completer<List<TeamAttributeScores>>? pending;

  @override
  Future<List<TeamAttributeSeasonOption>> loadOptionsForTeam(
          int teamId) async =>
      missing
          ? []
          : const [
              TeamAttributeSeasonOption(
                competitionId: 564,
                seasonId: 25659,
                seasonName: '2025/2026',
                isCurrent: false,
              ),
              TeamAttributeSeasonOption(
                competitionId: 564,
                seasonId: 27965,
                seasonName: '2026/2027',
                isCurrent: true,
              ),
            ];

  @override
  Future<List<TeamAttributeScores>> loadForTeam(int teamId,
      {int? seasonId}) async {
    requests.add((teamId, seasonId));
    if (fail) throw StateError('Temporary failure');
    if (teamId == 83 && pending != null) return pending!.future;
    return [_scores(teamId)];
  }
}
