import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/round_chart_window.dart';

void main() {
  test('keeps the latest 13 positions and centers the middle seven', () {
    final early = RoundChartWindow.endingAt(7);
    expect((early.firstRound, early.lastRound), (1, 13));
    expect((early.firstVisibleRound, early.centerRound, early.lastVisibleRound),
        (4, 7, 10));

    final later = RoundChartWindow.endingAt(20);
    expect((later.firstRound, later.lastRound), (8, 20));
    expect((later.firstVisibleRound, later.centerRound, later.lastVisibleRound),
        (11, 14, 17));
    expect(later.roundAt(140, 280), 14);
  });

  testWidgets('starts with seven centered rounds and scrolls across all 13',
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
    expect(scroll.controller!.offset, 70);
    await tester.tapAt(tester.getCenter(find.byType(RoundChartViewport)));
    expect(tappedRound, closeTo(14, 0.01));

    scroll.controller!.jumpTo(140);
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(RoundChartViewport)));
    expect(tappedRound, closeTo(17, 0.01));
  });
}
