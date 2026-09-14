import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Squad.dart';

void main() {
  test('exposes the nullable wage sort option', () {
    expect(SortOption.wage.label, 'Wage');

    const player = SquadPlayer(
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

    await tester.tap(find.text('POSITION'));
    await tester.pumpAndSettle();

    expect(find.text('WAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
