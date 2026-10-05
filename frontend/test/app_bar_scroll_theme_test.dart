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

  test('status bar icons contrast with the active theme', () {
    final light = app_style.whitetheme.appBarTheme.systemOverlayStyle!;
    final dark = app_style.darktheme.appBarTheme.systemOverlayStyle!;
    expect(light.statusBarIconBrightness, Brightness.dark);
    expect(light.statusBarBrightness, Brightness.light);
    expect(dark.statusBarIconBrightness, Brightness.light);
    expect(dark.statusBarBrightness, Brightness.dark);
    expect(light.statusBarColor, Colors.transparent);
    expect(dark.statusBarColor, Colors.transparent);
  });

  for (final theme in [app_style.whitetheme, app_style.darktheme]) {
    testWidgets('scrolling app bars follow ${theme.brightness} mode',
        (tester) async {
      late BuildContext pageContext;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(builder: (context) {
          pageContext = context;
          return const SizedBox.shrink();
        }),
      ));

      const background = Color(0xFFEBEBEB);
      for (final opacity in [0.0, 0.5, 1.0]) {
        final color = app_style.scrollingAppBarBackground(
            pageContext, background, opacity);
        expect(
            color,
            theme.brightness == Brightness.light
                ? background
                : Color.lerp(Colors.transparent, background, opacity));
      }
    });
  }
}
