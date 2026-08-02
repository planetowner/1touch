import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('theme switch updates the app theme', (tester) async {
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
          home: const Scaffold(body: AppThemeSwitch()),
        ),
      ),
    );

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.light,
    );
  });
}
