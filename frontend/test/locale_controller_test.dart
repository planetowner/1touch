import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/Preference.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('locale controller persists the user selection', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppLocaleController();

    await controller.initialize(deviceLocales: const [Locale('en')]);
    expect(controller.value, const Locale('en'));

    await controller.setLocale(const Locale('ja'));
    expect(controller.value, const Locale('ja'));

    final restored = AppLocaleController();
    await restored.initialize(deviceLocales: const [Locale('en')]);
    expect(restored.value, const Locale('ja'));
  });

  testWidgets('Preferences saves a language and rebuilds the app locale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await appLocaleController.setLocale(const Locale('en'));
    addTearDown(() => appLocaleController.setLocale(const Locale('en')));

    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: appLocaleController,
        builder: (_, locale, __) => MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: const PreferencePage(),
        ),
      ),
    );

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPDATE PREFERENCES'));
    await tester.pumpAndSettle();

    expect(appLocaleController.value, const Locale('ko'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app.locale'), 'ko');
  });
}
