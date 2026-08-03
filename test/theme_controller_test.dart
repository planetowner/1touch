import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme page backgrounds are white in light mode and black in dark mode',
      () {
    expect(
      app_style.whitetheme.extension<app_style.AppColors>()?.pageBackground,
      app_style.AppPalette.white,
    );
    expect(
      app_style.darktheme.extension<app_style.AppColors>()?.pageBackground,
      app_style.AppPalette.black,
    );
    expect(
      app_style.whitetheme.scaffoldBackgroundColor,
      app_style.AppPalette.white,
    );
  });

  test('theme controller defaults to dark and persists light mode', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppThemeController();

    await controller.initialize();
    expect(controller.value, ThemeMode.dark);

    await controller.setMode(ThemeMode.light);
    expect(controller.value, ThemeMode.light);

    final restoredController = AppThemeController();
    await restoredController.initialize();
    expect(restoredController.value, ThemeMode.light);
  });

  testWidgets('theme toggle matches the design and updates the app theme',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await appThemeController.setMode(ThemeMode.dark);
    addTearDown(() => appThemeController.setMode(ThemeMode.dark));

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeController,
        builder: (context, mode, _) => MaterialApp(
          theme: app_style.whitetheme,
          darkTheme: app_style.darktheme,
          themeMode: mode,
          home: const Scaffold(body: AppThemeToggle()),
        ),
      ),
    );

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
    expect(find.byIcon(Icons.brightness_4_outlined), findsOneWidget);

    var themeSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(themeSwitch.value, isFalse);
    expect(themeSwitch.inactiveThumbColor, app_style.AppPalette.white);
    expect(themeSwitch.inactiveTrackColor, app_style.AppPalette.darkGrey);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
    themeSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(themeSwitch.value, isTrue);
    expect(themeSwitch.activeThumbColor, app_style.AppPalette.white);
    expect(themeSwitch.activeTrackColor, app_style.AppPalette.darkGrey);
  });
}
