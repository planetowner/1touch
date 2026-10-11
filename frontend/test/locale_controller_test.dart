import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/preference.dart';
import 'package:onetouch/core/display_preferences.dart';
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

  for (final (languageCode, languageName, defaultCurrency) in [
    ('ko', 'Korean', DisplayCurrency.krw),
    ('ja', 'Japanese', DisplayCurrency.jpy),
    ('zh', 'Chinese', DisplayCurrency.cny),
    ('en', 'English', DisplayCurrency.eur),
  ]) {
    testWidgets('Preferences saves $languageCode with its default currency',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final sourceLanguage = languageCode == 'en' ? 'ko' : 'en';
      final sourceName = languageCode == 'en' ? 'Korean' : 'English';
      await appLocaleController.setLocale(Locale(sourceLanguage));
      await appDisplayPreferences
          .save(const DisplayPreferences(currency: DisplayCurrency.gbp));
      addTearDown(() {
        appDisplayPreferences.value = const DisplayPreferences();
        appLocaleController.value = const Locale('en');
      });

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
      await tester.pumpAndSettle();
      final preferenceContext = tester.element(find.byType(PreferencePage));
      String label(String text) => tr(preferenceContext, text);

      await tester.tap(find.text(label(sourceName)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label(sourceName)));
      await tester.pumpAndSettle();
      expect(find.text('GBP (£)'), findsOneWidget);

      await tester.tap(find.text(label(sourceName)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label(languageName)));
      await tester.pumpAndSettle();
      expect(find.text(defaultCurrency.label), findsOneWidget);
      expect(appDisplayPreferences.value.currency, DisplayCurrency.gbp);
      expect(appLocaleController.value.languageCode, sourceLanguage);

      await tester.tap(find.text(defaultCurrency.label));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(3));
      final selected = tester.widget<ListTile>(find.ancestor(
        of: find.byIcon(Icons.check),
        matching: find.byType(ListTile),
      ));
      expect((selected.title! as Text).data, defaultCurrency.label);
      await tester.tap(find.text(defaultCurrency.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(appLocaleController.value.languageCode, languageCode);
      expect(appDisplayPreferences.value.currency, defaultCurrency);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('app.locale'), languageCode);
      final restored = DisplayPreferencesController();
      await restored.initialize(languageCode: languageCode);
      expect(restored.value.currency, defaultCurrency);
      restored.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
