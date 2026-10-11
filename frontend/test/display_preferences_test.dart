import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/preference.dart';
import 'package:onetouch/core/display_preferences.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/Overview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/player_detail_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const currenciesByLanguage = {
    'en': [DisplayCurrency.eur, DisplayCurrency.gbp, DisplayCurrency.usd],
    'ko': [DisplayCurrency.krw, DisplayCurrency.eur, DisplayCurrency.gbp],
    'ja': [DisplayCurrency.jpy, DisplayCurrency.eur, DisplayCurrency.gbp],
    'zh': [DisplayCurrency.cny, DisplayCurrency.eur, DisplayCurrency.gbp],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appDisplayPreferences.value = const DisplayPreferences();
    appLocaleController.value = const Locale('en');
  });

  tearDown(() {
    appDisplayPreferences.value = const DisplayPreferences();
    appLocaleController.value = const Locale('en');
  });

  for (final language in currenciesByLanguage.entries) {
    test('uses the default currency for ${language.key} without a saved choice',
        () async {
      final controller = DisplayPreferencesController();
      await controller.initialize(languageCode: language.key);
      expect(controller.value.currency, language.value.first);
      controller.dispose();
    });

    test('restores the unit and allowed currency choices for ${language.key}',
        () async {
      for (final currency in language.value) {
        final controller = DisplayPreferencesController();
        await controller.save(DisplayPreferences(
          unit: MeasurementUnit.imperial,
          currency: currency,
        ));
        final restored = DisplayPreferencesController();
        await restored.initialize(languageCode: language.key);
        expect(restored.value.unit, MeasurementUnit.imperial);
        expect(restored.value.currency, currency);
        controller.dispose();
        restored.dispose();
      }
    });

    test(
        'replaces an old unsupported currency with the ${language.key} default',
        () async {
      final controller = DisplayPreferencesController();
      await controller.save(DisplayPreferences(
        unit: MeasurementUnit.imperial,
        currency:
            language.key == 'en' ? DisplayCurrency.krw : DisplayCurrency.usd,
      ));
      await controller.initialize(languageCode: language.key);
      expect(controller.value.currency, language.value.first);
      expect(controller.value.unit, MeasurementUnit.imperial);
      controller.dispose();
    });
  }

  test('formats measurements and preserves unavailable values', () {
    expect(MeasurementUnit.metric.formatHeight(183), '183cm');
    expect(MeasurementUnit.metric.formatWeight(78), '78kg');
    expect(MeasurementUnit.imperial.formatHeight(183), '6ft 0in');
    expect(MeasurementUnit.imperial.formatHeight(182), '6ft 0in');
    expect(MeasurementUnit.imperial.formatHeight(180), '5ft 11in');
    expect(MeasurementUnit.imperial.formatWeight(78), '172lb');
    for (final unit in MeasurementUnit.values) {
      expect(unit.formatHeight(null), '—');
      expect(unit.formatWeight(null), '—');
    }
  });

  Widget app(Widget home) => MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: home,
      );

  for (final language in currenciesByLanguage.entries) {
    testWidgets('shows exactly three currencies in order for ${language.key}',
        (tester) async {
      appLocaleController.value = Locale(language.key);
      await appDisplayPreferences.initialize(languageCode: language.key);
      await tester.pumpWidget(MaterialApp(
        locale: appLocaleController.value,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: const PreferencePage(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.value.first.label));
      await tester.pumpAndSettle();

      final options =
          tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(options.map((option) => (option.title! as Text).data),
          language.value.map((currency) => currency.label));
      expect(options.first.trailing, isA<Icon>());
      expect(
          options.skip(1).every((option) => option.trailing == null), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('save retains selections after reopening and restarting',
      (tester) async {
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const PreferencePage(),
          )),
          child: const Text('Open settings'),
        ),
      ),
    )));

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metric (cm)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Imperial (ft/in)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR (€)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD (\$)'));
    await tester.pumpAndSettle();
    expect(appDisplayPreferences.value.unit, MeasurementUnit.metric);
    expect(appDisplayPreferences.value.currency, DisplayCurrency.eur);

    await tester.tap(find.text('UPDATE PREFERENCES'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    appDisplayPreferences.value = const DisplayPreferences();
    await appDisplayPreferences.initialize(languageCode: 'en');
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Imperial (ft/in)'), findsOneWidget);
    expect(find.text('USD (\$)'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Korean'));
    await tester.pumpAndSettle();
    expect(find.text('KRW (₩)'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('USD (\$)'), findsOneWidget);

    await tester.tap(find.text('Imperial (ft/in)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metric (cm)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(appDisplayPreferences.value.unit, MeasurementUnit.imperial);
  });

  testWidgets('an open player biography responds to unit changes',
      (tester) async {
    final profile = detailFixture().profile;
    await tester.pumpWidget(app(Scaffold(
      body: PlayerBioStatsBlock(profile: profile),
    )));
    await tester.pumpAndSettle();
    expect(find.text('${profile.heightCm}cm'), findsOneWidget);
    expect(find.text('${profile.weightKg}kg'), findsOneWidget);

    await appDisplayPreferences.save(const DisplayPreferences(
      unit: MeasurementUnit.imperial,
    ));
    await tester.pumpAndSettle();
    expect(find.text('${profile.heightCm}cm'), findsNothing);
    expect(
      find.text(MeasurementUnit.imperial.formatHeight(profile.heightCm)),
      findsOneWidget,
    );
    expect(
      find.text(MeasurementUnit.imperial.formatWeight(profile.weightKg)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
