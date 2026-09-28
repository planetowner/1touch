import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/season_label.dart';

void main() {
  test('compacts full season years for display', () {
    expect(compactSeasonLabel('2026/2027'), '26/27');
    expect(compactSeasonLabel('2025/2026'), '25/26');
    expect(compactSeasonLabel('1999/2000'), '99/00');
  });

  test('keeps already compact and non-season labels intact', () {
    expect(compactSeasonLabel('26/27'), '26/27');
    expect(compactSeasonLabel('Current season'), 'Current season');
    expect(compactSeasonLabel(' 2024 / 2025 '), '24/25');
  });
}
