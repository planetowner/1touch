import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/match_info/live_match_motion.dart';

void main() {
  testWidgets('live dot fades out and back in over two seconds',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LivePulseDot()));
    double opacity() => tester
        .widget<FadeTransition>(
          find.byKey(const ValueKey('live-pulse-dot')),
        )
        .opacity
        .value;

    expect(opacity(), 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacity(), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacity(), closeTo(0, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacity(), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opacity(), closeTo(1, 0.01));
  });

  testWidgets('live line draws once and stays drawn', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LiveTrimLine()));
    double widthFactor() => tester
        .widget<FractionallySizedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('live-trim-line')),
            matching: find.byType(FractionallySizedBox),
          ),
        )
        .widthFactor!;

    expect(widthFactor(), 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(widthFactor(), closeTo(0.5, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(widthFactor(), 1);
    await tester.pump(const Duration(seconds: 1));
    expect(widthFactor(), 1);
  });

  testWidgets('reduced motion keeps both indicators visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Column(children: [LivePulseDot(), LiveTrimLine()]),
      ),
    ));
    expect(
      tester
          .widget<FadeTransition>(find.byKey(const ValueKey('live-pulse-dot')))
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<FractionallySizedBox>(find.descendant(
            of: find.byKey(const ValueKey('live-trim-line')),
            matching: find.byType(FractionallySizedBox),
          ))
          .widthFactor,
      1,
    );
  });
}
