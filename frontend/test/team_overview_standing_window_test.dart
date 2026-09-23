import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/models/standing.dart' as standing_model;

void main() {
  setUpAppCatalog();
  Widget subject(int teamId) {
    return MaterialApp(
      home: Scaffold(
        body: Standing(
          teams: <String, dynamic>{'id': teamId},
          repository: MockStandingRepository(),
        ),
      ),
    );
  }

  void expectPremierLeagueRows(WidgetTester tester, List<String> shortCodes) {
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(card, findsOneWidget);
    for (final shortCode in shortCodes) {
      expect(
        find.descendant(of: card, matching: find.text(shortCode)),
        findsOneWidget,
      );
    }
  }

  testWidgets('shows positions 1–5 when the selected team is first',
      (tester) async {
    await tester.pumpWidget(subject(9));

    expectPremierLeagueRows(tester, ['MCI', 'ARS', 'NEW', 'LIV', 'BOU']);
    final shell = tester.widget<Container>(
      find.byKey(const ValueKey('overview-standing-shell-8')),
    );
    expect(
      (shell.decoration as BoxDecoration).boxShadow,
      lightModeCardShadows,
    );
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(find.descendant(of: card, matching: find.text('BRE')), findsNothing);
  });

  testWidgets('shows positions 1–5 when the selected team is second',
      (tester) async {
    await tester.pumpWidget(subject(19));

    expectPremierLeagueRows(tester, ['MCI', 'ARS', 'NEW', 'LIV', 'BOU']);
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(find.descendant(of: card, matching: find.text('BRE')), findsNothing);
  });

  testWidgets('centers a lower-ranked team in the five-row window',
      (tester) async {
    await tester.pumpWidget(subject(6));

    expectPremierLeagueRows(tester, ['BHA', 'MUN', 'TOT', 'AVL', 'EVE']);
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(find.descendant(of: card, matching: find.text('CHE')), findsNothing);
  });

  testWidgets('uses 16px gaps between the standings stat columns',
      (tester) async {
    await tester.pumpWidget(subject(9));

    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    final tables = tester.widgetList<Table>(
      find.descendant(of: card, matching: find.byType(Table)),
    );
    final grid = tables.first.columnWidths!;
    for (final column in [4, 6, 8]) {
      expect((grid[column]! as FixedColumnWidth).value, 16);
    }
  });

  testWidgets('centers W, D, and L values beneath their labels',
      (tester) async {
    await tester.pumpWidget(subject(9));

    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    for (final stat in ['win', 'draw', 'loss']) {
      final header = tester.widget<Align>(
        find.descendant(
          of: card,
          matching: find.byKey(
            ValueKey('overview-standing-$stat-header'),
          ),
        ),
      );
      final firstValue = tester.widget<Align>(
        find.descendant(
          of: card,
          matching: find.byKey(
            ValueKey('overview-standing-$stat-1'),
          ),
        ),
      );
      expect(header.alignment, Alignment.center);
      expect(firstValue.alignment, Alignment.center);
    }
  });

  testWidgets('reports the competition selected from an overview card',
      (tester) async {
    int? selectedCompetitionId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Standing(
            teams: const <String, dynamic>{'id': 9},
            repository: MockStandingRepository(),
            onCompetitionSelected: (competitionId) {
              selectedCompetitionId = competitionId;
            },
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('overview-standing-card-8')),
    );

    expect(selectedCompetitionId, 8);
  });

  testWidgets('requests the backend-defined current domestic season',
      (tester) async {
    final repository = _RecordingStandingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Standing(
            teams: const <String, dynamic>{'id': 9},
            repository: repository,
          ),
        ),
      ),
    );

    expect(repository.requests, [(competitionId: 8, seasonId: null)]);
  });
}

class _RecordingStandingRepository extends MockStandingRepository {
  final List<({int competitionId, int? seasonId})> requests = [];

  @override
  Future<List<standing_model.Standing>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    requests.add((competitionId: competitionId, seasonId: seasonId));
    return super.loadForCompetition(competitionId, seasonId: seasonId);
  }
}
