import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'support/player_detail_fixture.dart';

void main() {
  testWidgets('same position compares categories without a radar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: FakePlayerDetailRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 3'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerStatCategories), findsOneWidget);
    expect(find.text('FINISH'), findsOneWidget);
    expect(find.text('xG'), findsOneWidget);
    expect(find.text('Pace'), findsNothing);
    expect(find.text('Shooting'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a different season position cannot be compared', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: FakePlayerDetailRepository())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAYER 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('same season position'), findsWidgets);
    expect(find.byType(PlayerStatCategories), findsNothing);
    expect(find.text('Player 2'), findsOneWidget);
  });
}
