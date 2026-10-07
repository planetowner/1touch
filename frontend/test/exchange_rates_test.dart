import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/display_preferences.dart';
import 'package:onetouch/data/exchange_rates/exchange_rates_repository.dart';
import 'package:onetouch/features/team/overview/transfer_fee.dart';

import 'support/exchange_rates_fixture.dart';

void main() {
  test('shares requests and refreshes rates after an hour', () async {
    var now = DateTime.utc(2026, 10, 7, 12);
    await withClock(Clock(() => now), () async {
      var requests = 0;
      final response = Completer<http.Response>();
      final repository = ExchangeRatesRepository(client: MockClient((request) {
        requests++;
        expect(request.url.host, 'api.frankfurter.dev');
        expect(request.url.path, '/v1/latest');
        expect(request.url.queryParameters['base'], 'EUR');
        expect(request.url.queryParameters['symbols'], 'USD,GBP,KRW,JPY');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return response.future;
      }));

      final first = repository.load();
      expect(repository.load(), same(first));
      response.complete(http.Response(jsonEncode(exchangeRatesFixture()), 200));
      final rates = await first;
      expect(rates.date, '2026-10-07');
      expect(
          rates.convertEuros(100, DisplayCurrency.usd), closeTo(111.77, .0001));
      expect(rates.convertEuros(100, DisplayCurrency.eur), 100);
      now = now.add(const Duration(minutes: 59));
      expect(repository.load(), same(first));
      expect(requests, 1);
      now = now.add(const Duration(minutes: 1));
      await repository.load();
      expect(requests, 2);
    });
  });

  test('failed requests can retry without caching an invalid result', () async {
    var requests = 0;
    final repository = ExchangeRatesRepository(client: MockClient((_) async {
      return ++requests == 1
          ? http.Response('Unavailable', 503)
          : http.Response(jsonEncode(exchangeRatesFixture()), 200);
    }));
    await expectLater(repository.load(), throwsA(isA<http.ClientException>()));
    expect((await repository.load()).rates[DisplayCurrency.krw], 1496.25);
    expect(requests, 2);
  });

  test('rejects a different base and incomplete or invalid quotes', () {
    for (final json in [
      exchangeRatesFixture()..['base'] = 'USD',
      exchangeRatesFixture()..['amount'] = 100,
      exchangeRatesFixture()..['rates'] = {'USD': 1.1},
      exchangeRatesFixture()..['rates']['KRW'] = 0.0,
      exchangeRatesFixture()..['rates']['JPY'] = -1.0,
    ]) {
      expect(() => ExchangeRates.fromJson(json), throwsFormatException);
    }
  });

  test('formats converted values for all five currencies', () {
    final rates = ExchangeRates.fromJson(exchangeRatesFixture());
    final expected = {
      DisplayCurrency.eur: '€22m',
      DisplayCurrency.usd: '\$24.6m',
      DisplayCurrency.gbp: '£18.6m',
      DisplayCurrency.krw: '₩32.9bn',
      DisplayCurrency.jpy: '¥3.9bn',
    };
    for (final entry in expected.entries) {
      expect(
          formatTransferFee(rates.convertEuros(22000000, entry.key), entry.key),
          entry.value);
    }
    expect(formatTransferFee(0, DisplayCurrency.eur), '€0');
    expect(formatTransferFee(8500, DisplayCurrency.eur), '€8.5k');
    expect(formatTransferFee(990, DisplayCurrency.eur), '€990');
  });
}
