import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';
import 'support/player_detail_fixture.dart';

void main() {
  setUpAppCatalog();
  testWidgets('same position shows the unavailable attribute message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: FakePlayerDetailRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('26/27'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('comparison-attribute-pending')),
        findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Pace'), findsNothing);
    expect(find.text('Shooting'), findsNothing);
    expect(find.text('FINISH'), findsOneWidget);
    expect(find.text('xG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('player picker only offers the same season position',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: FakePlayerDetailRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    expect(find.text('You can only pick players who play the same position.'),
        findsOneWidget);
    expect(find.text('Player 2'), findsNothing);
    expect(find.text('Player 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-attribute-pending')),
        findsNothing);
  });
}
