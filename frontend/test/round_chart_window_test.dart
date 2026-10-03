import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';

void main() {
  test('centers a selected round within seven visible round positions', () {
    final window = RoundChartWindow.centeredThrough(13);
    const viewportWidth = 140.0;
    const roundWidth = viewportWidth / 6;
    expect((window.firstRound, window.lastRound), (-2, 16));
    expect(window.centeredScrollOffset(7, viewportWidth), roundWidth * 6);
    expect(window.centeredScrollOffset(8, viewportWidth),
        closeTo(roundWidth * 7, 0.0001));
    expect(window.centeredScrollOffset(13, viewportWidth), roundWidth * 12);
  });

  test('keeps a full round box inside the seven-round viewport', () {
    final window = RoundChartWindow.centeredThrough(13);
    const viewportWidth = 288.0;
    const tooltipWidth = 155.0;
    for (final round in [1, 7, 8, 13]) {
      final visibleLeft = window.centeredScrollOffset(round, viewportWidth);
      for (final preferLeft in [true, false]) {
        final left = roundChartTooltipLeft(
          roundWindow: window,
          round: round,
          viewportWidth: viewportWidth,
          tooltipWidth: tooltipWidth,
          gap: 8,
          preferLeft: preferLeft,
        );
        expect(left, greaterThanOrEqualTo(visibleLeft));
        expect(left + tooltipWidth,
            lessThanOrEqualTo(visibleLeft + viewportWidth));
      }
    }
  });

  testWidgets('only dragging the handle moves the selection and recenters it',
      (tester) async {
    final window = RoundChartWindow.centeredThrough(13);
    var selectedRound = 7;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 140,
            height: 100,
            child: StatefulBuilder(
              builder: (context, setState) => RoundChartViewport(
                roundWindow: window,
                viewportSize: const Size(140, 100),
                selectedRound: selectedRound,
                selectableRounds: [
                  for (var round = 1; round <= 13; round++) round
                ],
                onRoundChanged: (round) =>
                    setState(() => selectedRound = round),
                builder: (_, size) => const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    ));

    final viewport = find.byType(RoundChartViewport);
    final handle = find.byKey(const ValueKey('round-chart-selection-handle'));
    final viewportRect = tester.getRect(viewport);
    final scroll = tester.widget<SingleChildScrollView>(
      find.descendant(
          of: viewport, matching: find.byType(SingleChildScrollView)),
    );
    expect(scroll.controller!.offset, closeTo(140, 0.01));
    expect(tester.getRect(handle).left + RoundChartSelectionHandle.tipInset,
        closeTo(viewportRect.center.dx, 0.1));

    await tester.tapAt(Offset(viewportRect.center.dx, viewportRect.top + 15));
    await tester.pump();
    expect(selectedRound, 7);

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(140 / 6, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selectedRound, 8);
    expect(scroll.controller!.offset, closeTo(140 + 140 / 6, 0.01));
    expect(tester.getRect(handle).left + RoundChartSelectionHandle.tipInset,
        closeTo(viewportRect.center.dx, 0.1));

    final continuousDrag = await tester.startGesture(tester.getCenter(handle));
    await continuousDrag.moveBy(const Offset(140 / 6, 0));
    await tester.pumpAndSettle();
    expect(selectedRound, 9);
    await continuousDrag.moveBy(const Offset(140 / 6, 0));
    await tester.pumpAndSettle();
    expect(selectedRound, 10);
    await continuousDrag.moveBy(const Offset(-140 / 6, 0));
    await continuousDrag.up();
    await tester.pumpAndSettle();
    expect(selectedRound, 9);
    expect(scroll.controller!.offset, closeTo(140 + 2 * 140 / 6, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects the nearest available round when data skips rounds',
      (tester) async {
    final window = RoundChartWindow.centeredThrough(7);
    var selectedRound = 1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 140,
            height: 100,
            child: StatefulBuilder(
              builder: (context, setState) => RoundChartViewport(
                roundWindow: window,
                viewportSize: const Size(140, 100),
                selectedRound: selectedRound,
                selectableRounds: const [1, 3, 7],
                onRoundChanged: (round) =>
                    setState(() => selectedRound = round),
                builder: (_, size) => const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    ));

    final handle = find.byKey(const ValueKey('round-chart-selection-handle'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(140 / 6 * 1.2, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selectedRound, 3);
    expect(tester.takeException(), isNull);
  });
}
