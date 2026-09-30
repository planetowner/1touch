import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;

void main() {
  test('app bars retain their surface color when content scrolls beneath', () {
    for (final theme in [app_style.whitetheme, app_style.darktheme]) {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.shadowColor, Colors.transparent);
    }
  });
}
