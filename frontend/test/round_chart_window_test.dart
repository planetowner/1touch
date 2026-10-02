import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/round_chart_window.dart';

void main() {
  test('shows every completed early round and then the latest seven', () {
    final early = RoundChartWindow.endingAt(4);
    expect((early.firstRound, early.lastRound), (1, 7));
    expect((early.firstVisibleRound, early.centerRound, early.lastVisibleRound),
        (1, 4, 7));
    expect([1, 2, 3, 4].every(early.contains), isTrue);
    expect(early.initialScrollOffset(140), 0);

    final eighth = RoundChartWindow.endingAt(8);
    expect((eighth.firstRound, eighth.lastRound), (1, 8));
    expect(
        (eighth.firstVisibleRound, eighth.centerRound, eighth.lastVisibleRound),
        (2, 5, 8));

    final later = RoundChartWindow.endingAt(20);
    expect((later.firstRound, later.lastRound), (8, 20));
    expect((later.firstVisibleRound, later.centerRound, later.lastVisibleRound),
        (14, 17, 20));
    expect(later.roundAt(140, 280), 14);
  });

  testWidgets('starts on the latest seven and scrolls across the previous six',
      (tester) async {
    final window = RoundChartWindow.endingAt(20);
    double? tappedRound;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 140,
            height: 100,
            child: RoundChartViewport(
              roundWindow: window,
              viewportSize: const Size(140, 100),
              builder: (_, size) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => tappedRound =
                    window.roundAt(details.localPosition.dx, size.width),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    ));

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.controller!.offset, 140);
    await tester.tapAt(tester.getCenter(find.byType(RoundChartViewport)));
    expect(tappedRound, closeTo(17, 0.01));

    scroll.controller!.jumpTo(0);
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(RoundChartViewport)));
    expect(tappedRound, closeTo(11, 0.01));
  });

  testWidgets('round eight initially shows rounds two through eight',
      (tester) async {
    final window = RoundChartWindow.endingAt(8);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 140,
          height: 100,
          child: RoundChartViewport(
            roundWindow: window,
            viewportSize: const Size(140, 100),
            builder: (_, size) => SizedBox.fromSize(size: size),
          ),
        ),
      ),
    ));

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.controller!.offset, closeTo(140 / 6, 0.01));
    expect(window.roundAt(scroll.controller!.offset, window.contentWidth(140)),
        closeTo(2, 0.01));
    expect(
      window.roundAt(scroll.controller!.offset + 140, window.contentWidth(140)),
      closeTo(8, 0.01),
    );
  });

  testWidgets('selection handle stays on its round while the viewport scrolls',
      (tester) async {
    final window = RoundChartWindow.endingAt(20);
    final movedX = <double>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 140,
            height: 100,
            child: RoundChartViewport(
              roundWindow: window,
              viewportSize: const Size(140, 100),
              selectedRound: 17,
              onPointerMove: movedX.add,
              builder: (_, size) => const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ));

    final viewport = find.byType(RoundChartViewport);
    final handle = find.byKey(const ValueKey('round-chart-selection-handle'));
    final viewportRect = tester.getRect(viewport);
    expect(tester.getRect(handle).left + RoundChartSelectionHandle.tipInset,
        closeTo(viewportRect.center.dx, 0.1));
    expect(tester.getRect(handle).top,
        viewportRect.bottom - RoundChartSelectionHandle.height);
    expect(
        tester.getSize(handle),
        const Size(
            RoundChartSelectionHandle.width, RoundChartSelectionHandle.height));

    final gesture = await tester.startGesture(viewportRect.center);
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(movedX, isNotEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(handle).left + RoundChartSelectionHandle.tipInset,
        greaterThan(viewportRect.center.dx));
    expect(tester.takeException(), isNull);
  });
}
