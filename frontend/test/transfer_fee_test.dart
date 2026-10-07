import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/comm_pages/Profile_settings/preference.dart';
import 'package:onetouch/core/display_preferences.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/data/exchange_rates/exchange_rates_repository.dart';
import 'package:onetouch/features/team/overview/transfer_fee.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/exchange_rates_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appDisplayPreferences.value =
        const DisplayPreferences(currency: DisplayCurrency.eur);
    appLocaleController.value = const Locale('en');
  });
  tearDown(() => appDisplayPreferences.value = const DisplayPreferences());

  Widget app(Widget child) => MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(body: child),
      );

  testWidgets('saving currency updates an open fee and restores on restart',
      (tester) async {
    var requests = 0;
    final repository = ExchangeRatesRepository(client: MockClient((_) async {
      requests++;
      return http.Response(jsonEncode(exchangeRatesFixture()), 200);
    }));
    await tester.pumpWidget(app(Builder(
        builder: (context) => Column(children: [
              TransferFee(amountInEuros: 22000000, repository: repository),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const PreferencePage(),
                )),
                child: const Text('Open settings'),
              ),
            ]))));
    await tester.pumpAndSettle();
    expect(find.text('€22m'), findsOneWidget);
    expect(requests, 0);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EUR (€)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KRW (₩)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPDATE PREFERENCES'));
    await tester.pumpAndSettle();
    expect(find.text('₩32.9bn'), findsOneWidget);
    expect(find.byTooltip('ECB exchange rate · 2026-10-07'), findsOneWidget);
    expect(requests, 1);
    final restored = DisplayPreferencesController();
    await restored.initialize();
    expect(restored.value.currency, DisplayCurrency.krw);
    restored.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending fees share a request and follow the latest selection',
      (tester) async {
    appDisplayPreferences.value = const DisplayPreferences();
    var requests = 0;
    final response = Completer<http.Response>();
    final repository = ExchangeRatesRepository(client: MockClient((_) {
      requests++;
      return response.future;
    }));
    await tester.pumpWidget(app(Column(children: [
      TransferFee(amountInEuros: 22000000, repository: repository),
      TransferFee(amountInEuros: 22000000, repository: repository),
    ])));
    expect(find.text('…'), findsNWidgets(2));
    expect(requests, 1);
    appDisplayPreferences.value =
        const DisplayPreferences(currency: DisplayCurrency.jpy);
    await tester.pump();
    response.complete(http.Response(jsonEncode(exchangeRatesFixture()), 200));
    await tester.pumpAndSettle();
    expect(find.text('¥3.9bn'), findsNWidgets(2));
    expect(find.text('\$24.6m'), findsNothing);
    expect(requests, 1);
  });

  testWidgets('failed conversion has a working retry and never relabels euros',
      (tester) async {
    appDisplayPreferences.value = const DisplayPreferences();
    var requests = 0;
    final repository = ExchangeRatesRepository(client: MockClient((_) async {
      return ++requests == 1
          ? http.Response('Unavailable', 503)
          : http.Response(jsonEncode(exchangeRatesFixture()), 200);
    }));
    await tester.pumpWidget(
        app(TransferFee(amountInEuros: 22000000, repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
    expect(find.text('\$22m'), findsNothing);
    await tester.tap(find.text('—'));
    await tester.pumpAndSettle();
    expect(find.text('\$24.6m'), findsOneWidget);
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });

  for (final refreshSucceeds in [true, false]) {
    testWidgets(
        'keeps the last rate visible during refresh, success=$refreshSucceeds',
        (tester) async {
      var now = DateTime.utc(2026, 10, 7, 12);
      await withClock(Clock(() => now), () async {
        appDisplayPreferences.value = const DisplayPreferences();
        final refresh = Completer<http.Response>();
        var requests = 0;
        final repository =
            ExchangeRatesRepository(client: MockClient((_) async {
          if (++requests > 1) return refresh.future;
          return http.Response(jsonEncode(exchangeRatesFixture()), 200);
        }));
        await tester.pumpWidget(
            app(TransferFee(amountInEuros: 22000000, repository: repository)));
        await tester.pumpAndSettle();
        expect(find.text('\$24.6m'), findsOneWidget);

        now = now.add(const Duration(days: 1));
        appDisplayPreferences.value =
            const DisplayPreferences(currency: DisplayCurrency.krw);
        await tester.pump();
        expect(requests, 2);
        expect(find.text('₩32.9bn'), findsOneWidget);
        expect(find.text('…'), findsNothing);

        final updated = exchangeRatesFixture()
          ..['date'] = '2026-10-08'
          ..['rates']['KRW'] = 1500.0;
        refresh.complete(refreshSucceeds
            ? http.Response(jsonEncode(updated), 200)
            : http.Response('Unavailable', 503));
        await tester.pumpAndSettle();
        expect(
            find.text(refreshSucceeds ? '₩33bn' : '₩32.9bn'), findsOneWidget);
        expect(
            find.byTooltip(
                'ECB exchange rate · ${refreshSucceeds ? '2026-10-08' : '2026-10-07'}'),
            findsOneWidget);
        expect(find.text('—'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
