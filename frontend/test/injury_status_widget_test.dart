import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/models/team_injury_report.dart';

void main() {
  Widget buildSubject({
    required int teamId,
    required TeamInjuryRepository repository,
  }) {
    return MaterialApp(
      theme: whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: InjuryStatus(
            teams: <String, dynamic>{'id': teamId},
            repository: repository,
          ),
        ),
      ),
    );
  }

  testWidgets('renders players and every reported injury without estimates',
      (tester) async {
    final result = Completer<TeamInjuryReport>();
    final repository = _TestTeamInjuryRepository((_) => result.future);
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));

    expect(find.byKey(const ValueKey('injury-loading')), findsOneWidget);

    result.complete(_report(teamId: 83));
    await tester.pumpAndSettle();

    expect(find.text('Injured Player'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Hamstring • Sep 1, 2026 – Sep 20, 2026'), findsOneWidget);
    expect(find.text('Knock'), findsOneWidget);
    expect(find.textContaining('Back in'), findsNothing);
    expect(find.byKey(const ValueKey('injury-5001')), findsOneWidget);
    expect(find.byKey(const ValueKey('injury-5002')), findsOneWidget);
  });

  testWidgets('shows the API empty state', (tester) async {
    final repository = _TestTeamInjuryRepository(
      (teamId) async => TeamInjuryReport(
        teamId: teamId,
        seasonId: 25659,
        players: const [],
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('injury-empty')), findsOneWidget);
    expect(find.text('No current injuries'), findsOneWidget);
  });

  testWidgets('shows an error and retries the repository request',
      (tester) async {
    var attempt = 0;
    final repository = _TestTeamInjuryRepository((teamId) async {
      attempt += 1;
      if (attempt == 1) throw StateError('temporary failure');
      return TeamInjuryReport(
        teamId: teamId,
        seasonId: 25659,
        players: const [],
      );
    });
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('injury-error')), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.byKey(const ValueKey('injury-empty')), findsOneWidget);
  });

  testWidgets('ignores a stale result after the selected team changes',
      (tester) async {
    final firstResult = Completer<TeamInjuryReport>();
    final secondResult = Completer<TeamInjuryReport>();
    final repository = _TestTeamInjuryRepository(
      (teamId) => teamId == 83 ? firstResult.future : secondResult.future,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 83, repository: repository));
    await tester.pumpWidget(buildSubject(teamId: 19, repository: repository));

    firstResult.complete(_report(teamId: 83, playerName: 'Stale Player'));
    await tester.pump();

    expect(find.text('Stale Player'), findsNothing);
    expect(find.byKey(const ValueKey('injury-loading')), findsOneWidget);

    secondResult.complete(_report(teamId: 19, playerName: 'Current Player'));
    await tester.pumpAndSettle();

    expect(find.text('Stale Player'), findsNothing);
    expect(find.text('Current Player'), findsOneWidget);
  });
}

TeamInjuryReport _report({
  required int teamId,
  String playerName = 'Injured Player',
}) {
  return TeamInjuryReport(
    teamId: teamId,
    seasonId: 25659,
    players: [
      InjuredTeamPlayer(
        playerId: 1001,
        playerName: playerName,
        jerseyNumber: 10,
        injuries: [
          TeamPlayerInjury(
            sidelineId: 5001,
            typeId: 2,
            typeName: 'Hamstring',
            startDate: DateTime.utc(2026, 9, 1),
            endDate: DateTime.utc(2026, 9, 20),
          ),
          const TeamPlayerInjury(
            sidelineId: 5002,
            typeId: 3,
            typeName: 'Knock',
          ),
        ],
      ),
    ],
  );
}

class _TestTeamInjuryRepository implements TeamInjuryRepository {
  _TestTeamInjuryRepository(this._loader);

  final Future<TeamInjuryReport> Function(int teamId) _loader;
  final ValueNotifier<Map<int, TeamInjuryReport>> _cachedReports =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamInjuryReport>> get cachedReports =>
      _cachedReports;

  @override
  TeamInjuryReport? cachedForTeam(int teamId) => _cachedReports.value[teamId];

  @override
  Future<TeamInjuryReport> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    final report = await _loader(teamId);
    _cachedReports.value = Map.unmodifiable({
      ..._cachedReports.value,
      teamId: report,
    });
    return report;
  }

  void dispose() => _cachedReports.dispose();
}
