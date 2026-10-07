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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appDisplayPreferences.value = const DisplayPreferences();
    appLocaleController.value = const Locale('en');
  });

  tearDown(() {
    appDisplayPreferences.value = const DisplayPreferences();
    appLocaleController.value = const Locale('en');
  });

  test('restores the selected unit and every supported currency', () async {
    for (final currency in DisplayCurrency.values) {
      final controller = DisplayPreferencesController();
      await controller.save(DisplayPreferences(
        unit: MeasurementUnit.imperial,
        currency: currency,
      ));
      final restored = DisplayPreferencesController();
      await restored.initialize();
      expect(restored.value.unit, MeasurementUnit.imperial);
      expect(restored.value.currency, currency);
      controller.dispose();
      restored.dispose();
    }
  });

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
    await tester.tap(find.text('USD (\$)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KRW (₩)'));
    await tester.pumpAndSettle();
    expect(appDisplayPreferences.value.unit, MeasurementUnit.metric);
    expect(appDisplayPreferences.value.currency, DisplayCurrency.usd);

    await tester.tap(find.text('UPDATE PREFERENCES'));
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    appDisplayPreferences.value = const DisplayPreferences();
    await appDisplayPreferences.initialize();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Imperial (ft/in)'), findsOneWidget);
    expect(find.text('KRW (₩)'), findsOneWidget);

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
