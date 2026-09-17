import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';

void main() {
  Widget subject(int teamId) {
    return MaterialApp(
      home: Scaffold(
        body: Standing(teams: <String, dynamic>{'id': teamId}),
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
}
