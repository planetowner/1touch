import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/l10n/app_localizations.dart';
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

  void expectPremierLeagueRows(WidgetTester tester, List<String> teamNames) {
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(card, findsOneWidget);
    for (final teamName in teamNames) {
      expect(
        find.descendant(of: card, matching: find.text(teamName)),
        findsOneWidget,
      );
    }
  }

  testWidgets('shows positions 1–5 when the selected team is first',
      (tester) async {
    await tester.pumpWidget(subject(9));

    expectPremierLeagueRows(tester, [
      'Manchester City',
      'Arsenal',
      'Newcastle United',
      'Liverpool',
      'AFC Bournemouth',
    ]);
    final shell = tester.widget<Container>(
      find.byKey(const ValueKey('overview-standing-shell-8')),
    );
    expect(
      (shell.decoration as BoxDecoration).boxShadow,
      lightModeCardShadows,
    );
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(
      find.descendant(of: card, matching: find.text('Brentford')),
      findsNothing,
    );
  });

  testWidgets('shows positions 1–5 when the selected team is second',
      (tester) async {
    await tester.pumpWidget(subject(19));

    expectPremierLeagueRows(tester, [
      'Manchester City',
      'Arsenal',
      'Newcastle United',
      'Liverpool',
      'AFC Bournemouth',
    ]);
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(
      find.descendant(of: card, matching: find.text('Brentford')),
      findsNothing,
    );
  });

  testWidgets('centers a lower-ranked team in the five-row window',
      (tester) async {
    await tester.pumpWidget(subject(6));

    expectPremierLeagueRows(tester, [
      'Brighton & Hove Albion',
      'Manchester United',
      'Tottenham Hotspur',
      'Aston Villa',
      'Everton',
    ]);
    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    expect(
      find.descendant(of: card, matching: find.text('Chelsea')),
      findsNothing,
    );
  });

  testWidgets('uses the reference padding and standings column spacing',
      (tester) async {
    await tester.pumpWidget(subject(9));

    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    final tables = tester.widgetList<Table>(
      find.descendant(of: card, matching: find.byType(Table)),
    );
    final grid = tables.first.columnWidths!;
    expect((grid[0]! as FixedColumnWidth).value, 24);
    expect((grid[2]! as FixedColumnWidth).value, 16);
    for (final column in [4, 6, 8, 10]) {
      expect((grid[column]! as FixedColumnWidth).value, 15);
    }

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('overview-standing-header-8')),
    );
    final body = tester.widget<Padding>(
      find.byKey(const ValueKey('overview-standing-body-8')),
    );
    expect(header.padding, const EdgeInsets.symmetric(horizontal: 24));
    expect(body.padding, const EdgeInsets.fromLTRB(24, 16, 24, 24));
  });

  testWidgets('centers Pts, MP, W, D, and L values beneath their labels',
      (tester) async {
    await tester.pumpWidget(subject(9));

    final card = find.byKey(const ValueKey('overview-standing-card-8'));
    for (final stat in ['points', 'mp', 'win', 'draw', 'loss']) {
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

    final orderedHeaders = ['points', 'mp', 'win', 'draw', 'loss']
        .map(
          (stat) => tester.getCenter(
            find.descendant(
              of: card,
              matching: find.byKey(
                ValueKey('overview-standing-$stat-header'),
              ),
            ),
          ),
        )
        .toList();
    for (var index = 1; index < orderedHeaders.length; index++) {
      expect(
          orderedHeaders[index].dx, greaterThan(orderedHeaders[index - 1].dx));
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-standing-points-1')),
        matching: find.text('92'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the Korean matches-played header on one line',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
          body: Standing(
            teams: const <String, dynamic>{'id': 9},
            repository: MockStandingRepository(),
          ),
        ),
      ),
    );

    final header = find.byKey(
      const ValueKey('overview-standing-mp-header'),
    );
    final label = tester.widget<Text>(
      find.descendant(of: header, matching: find.text('경기')),
    );
    expect(label.maxLines, 1);
    expect(label.softWrap, isFalse);
    expect(
      find.descendant(of: header, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
