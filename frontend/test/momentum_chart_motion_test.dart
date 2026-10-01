import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/features/match_info/match_motion.dart';

void main() {
  test('momentum uses the specified ease-in-out timing', () {
    expect(matchMotionDurationMs, 833);
    expect(matchMotionCurve.transform(0), 0);
    expect(matchMotionCurve.transform(0.1), lessThan(0.1));
    expect(matchMotionCurve.transform(0.9), greaterThan(0.9));
    expect(matchMotionCurve.transform(1), 1);
  });

  testWidgets('past-match graph reveals once when scrolled into view',
      (tester) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: outer,
            child: Column(
              children: [
                const SizedBox(height: 1000),
                SingleChildScrollView(
                  child: MomentumChart(
                    animate: true,
                    values: const [-1, 1, -0.5, 0.8],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    expect(_revealProgress(tester), 0);
    outer.jumpTo(850);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(_revealProgress(tester), inInclusiveRange(0.1, 0.9));
    await tester.pump(const Duration(milliseconds: 383));
    expect(_revealProgress(tester), 1);
    await tester.pumpAndSettle();
    expect(_revealProgress(tester), 1);
    outer.jumpTo(0);
    await tester.pump();
    outer.jumpTo(850);
    await tester.pump();
    expect(_revealProgress(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live graph is shown without an entrance animation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MomentumChart(values: [-1, 1])),
    ));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_revealProgress(tester), 1);
    expect(find.text('MOMENTUM'), findsOneWidget);
    expect(find.text('45’'), findsOneWidget);
  });

  testWidgets('reduced motion skips the past-match animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: MomentumChart(animate: true)),
      ),
    ));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_revealProgress(tester), 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(430, 900)]) {
    testWidgets('momentum fits ${size.width.toInt()}px screen', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: MomentumChart())),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

double _revealProgress(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(MomentumChart),
    matching: find.byType(CustomPaint),
  ));
  return ((paint.painter! as dynamic).reveal.value as double);
}
