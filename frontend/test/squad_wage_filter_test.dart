import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/team/squad/squad_player_presentation.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Squad.dart';

void main() {
  test('exposes the nullable wage sort option', () {
    expect(SortOption.wage.label, 'Wage');

    final player = SquadPlayer(
      id: 1,
      name: 'Player',
      teamLabel: 'Team • 1',
      jerseyNumber: 1,
      position: Position.GK,
      age: 25,
      contractEndYear: 2028,
    );
    expect(player.estimatedWeeklyGrossEur, isNull);
  });

  testWidgets('shows WAGE in the existing Squad sort menu', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: const Scaffold(
          body: SquadTab(team: {'id': 83}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('25/26'), findsOneWidget);
    await tester.tap(find.text('POSITION'));
    await tester.pumpAndSettle();

    expect(find.text('WAGE'), findsOneWidget);
    expect(find.text('CONTRACT LENGTH'), findsOneWidget);
    final dropdown = find.byKey(const ValueKey('squad-sort-dropdown'));
    final arrow = find.byKey(const ValueKey('squad-sort-arrow'));
    final ascendingCheck = find.byKey(
      const ValueKey('squad-sort-selected-icon-ASCENDING'),
    );
    final positionCheck = find.byKey(
      const ValueKey('squad-sort-selected-icon-POSITION'),
    );
    expect(tester.getSize(dropdown).width, 172);
    expect(
      tester.getRect(dropdown).right - tester.getRect(arrow).right,
      8,
    );
    expect(
      tester.getRect(dropdown).right - tester.getRect(ascendingCheck).right,
      8,
    );
    expect(
      tester.getRect(dropdown).right - tester.getRect(positionCheck).right,
      8,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('places season before sort and hides contract length in history',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: const Scaffold(
          body: SquadTab(team: {'id': 83}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));

    final season = find.byKey(const ValueKey('squad-season-dropdown'));
    final sort = find.byKey(const ValueKey('squad-sort-dropdown'));
    expect(tester.getRect(season).right, lessThan(tester.getRect(sort).left));

    await tester.tap(find.byKey(const ValueKey('squad-season-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('24/25'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('squad-season-option-23621')),
    );
    await tester.pumpAndSettle();
    expect(find.text('24/25'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('squad-sort-arrow')));
    await tester.pumpAndSettle();
    expect(find.text('CONTRACT LENGTH'), findsNothing);
    expect(find.text('WAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
