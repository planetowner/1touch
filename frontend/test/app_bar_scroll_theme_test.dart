import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/main.dart' as app;

void main() {
  for (final theme in [app_style.whitetheme, app_style.darktheme]) {
    testWidgets(
        'status bar surface follows the visible route in ${theme.brightness}',
        (tester) async {
      late BuildContext pageContext;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(builder: (context) {
          pageContext = context;
          return const SizedBox.shrink();
        }),
      ));

      final isLight = theme.brightness == Brightness.light;
      expect(app.statusBarBackgroundForPath(pageContext, '/'),
          isLight ? Colors.white : Colors.black);
      expect(
          app.statusBarBackgroundForPath(pageContext, '/home'),
          isLight
              ? app_style.AppPalette.lightModeDarkGrey
              : app_style.AppPalette.black);
      expect(
          app.statusBarBackgroundForPath(pageContext, '/profile'),
          isLight
              ? app_style.AppPalette.lightGreyBox
              : app_style.AppPalette.black);
      expect(app.statusBarBackgroundForPath(pageContext, '/profile/preference'),
          isLight ? Colors.white : app_style.AppPalette.black);
    });
  }

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

  for (final (size, topInset) in [
    (const Size(320, 568), 24.0),
    (const Size(430, 932), 54.0),
  ]) {
    testWidgets('app bar spacing stays below the shared SafeArea at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: topInset);
      tester.view.viewPadding = FakeViewPadding(top: topInset);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);

      await tester.pumpWidget(MaterialApp(
        home: SafeArea(
          bottom: false,
          child: Builder(builder: (context) {
            expect(MediaQuery.paddingOf(context).top, 0);
            expect(app_style.appStatusBarInset(context), topInset);
            expect(
              app_style.appBarContentTop(context),
              (app_style.appBarMinimumContentTop - topInset).clamp(0, 47),
            );
            return const SizedBox.expand();
          }),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  }

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
