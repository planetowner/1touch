import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/team_comparison_colors.dart';

void main() {
  test('calculates WCAG contrast and OKLab distance', () {
    expect(
      ColorUtils.getContrastRatio(Colors.black, Colors.white),
      closeTo(21, 0.001),
    );
    expect(ColorUtils.okLabDistance(Colors.red, Colors.red), closeTo(0, 1e-9));
    expect(
        ColorUtils.okLabDistance(Colors.red, Colors.green), greaterThan(.12));
  });

  test('uses the first opponent palette color that passes both thresholds', () {
    final selected = TeamComparisonColorResolver.resolveOpponentColor(
      anchor: Colors.red,
      candidates: const [Colors.red, Colors.green, Colors.blue],
      background: Colors.black,
    );

    expect(selected, Colors.green);
  });

  test('falls back to white when no opponent color passes', () {
    final selected = TeamComparisonColorResolver.resolveOpponentColor(
      anchor: Colors.red,
      candidates: const [Colors.red, Color(0xFFFF0101), Color(0xFFFE0000)],
      background: Colors.black,
    );

    expect(selected, Colors.white);
  });

  test('resolves supplied team primary, secondary, and tertiary colors', () {
    final palette = TeamComparisonColorResolver.paletteFor(
      teamName: 'Manchester City',
    );

    expect(palette.primary, const Color(0xFF5FAFF1));
    expect(palette.secondary, const Color(0xFFF9C250));
    expect(palette.tertiary, const Color(0xFF296DCA));
  });
}
