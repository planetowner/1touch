import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/betting/bet_settlement_notifications.dart';
import 'package:onetouch/models/betting.dart';

void main() {
  const notice = BetSettlementNotice(
    bet: FixtureBet(
      betId: 7,
      fixtureId: 83,
      outcome: BetOutcome.homeWin,
      stake: 100,
      probabilityText: '0.200000000000000000',
      decimalOdds: 5,
      potentialReturn: 500,
      status: 'won',
      revision: 2,
      payout: 500,
    ),
    selectionName: 'Barcelona',
  );

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required VoidCallback onDismiss,
    VoidCallback? onSeeResults,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              BetSettlementResultOverlay(
                notice: notice,
                onDismiss: onDismiss,
                onSeeResults: onSeeResults ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('shows the settled result above the main navigation area',
      (tester) async {
    await pumpOverlay(tester, onDismiss: () {});

    expect(find.text('You won 500 points!'), findsOneWidget);
    expect(
      find.textContaining('Barcelona', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('SEE RESULTS'), findsOneWidget);
    expect(find.text('MAYBE LATER'), findsOneWidget);
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('bet-settlement-sheet')))
          .dy,
      784,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismisses from the empty area, close, and maybe later',
      (tester) async {
    var dismissCount = 0;
    await pumpOverlay(tester, onDismiss: () => dismissCount++);

    await tester.tapAt(const Offset(12, 12));
    expect(dismissCount, 1);

    await tester.tap(find.byKey(const ValueKey('bet-settlement-close-button')));
    expect(dismissCount, 2);

    await tester.tap(find.byKey(const ValueKey('bet-settlement-maybe-later')));
    expect(dismissCount, 3);
  });

  testWidgets('keeps taps inside the sheet from dismissing it', (tester) async {
    var dismissCount = 0;
    await pumpOverlay(tester, onDismiss: () => dismissCount++);

    final sheet = tester.getRect(
      find.byKey(const ValueKey('bet-settlement-sheet')),
    );
    await tester.tapAt(Offset(12, sheet.top + 12));
    expect(dismissCount, 0);
  });
}
