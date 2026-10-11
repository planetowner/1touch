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
        expect(request.url.queryParameters['symbols'], 'USD,GBP,KRW,JPY,CNY');
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

  test('formats converted values for all supported currencies', () {
    final rates = ExchangeRates.fromJson(exchangeRatesFixture());
    final expected = {
      DisplayCurrency.eur: '€22m',
      DisplayCurrency.usd: '\$25m',
      DisplayCurrency.gbp: '£19m',
      DisplayCurrency.krw: '329억 원',
      DisplayCurrency.jpy: '39億円',
      DisplayCurrency.cny: '2亿元',
    };
    for (final entry in expected.entries) {
      expect(
          formatTransferFee(rates.convertEuros(22000000, entry.key), entry.key),
          entry.value);
    }
  });

  test('keeps small positive fees visible in fixed hundred-million units', () {
    const units = {
      DisplayCurrency.krw: '억 원',
      DisplayCurrency.cny: '亿元',
      DisplayCurrency.jpy: '億円',
    };
    const amounts = {
      0: '0',
      1: '<0.1',
      1000000: '<0.1',
      4999999: '<0.1',
      5000000: '0.1',
      5000001: '0.1',
      14000000: '0.1',
      15000000: '0.2',
      29931549: '0.3',
      49000000: '0.5',
      50000000: '0.5',
      76000000: '0.8',
      94000000: '0.9',
      95000000: '1',
      96000000: '1',
      99999999: '1',
      100000000: '1',
      100000001: '1',
      149000000: '1',
      150000000: '2',
      1000000000: '10',
      6000000000: '60',
      6060000000: '61',
      99994000000: '1,000',
      99996000000: '1,000',
      140000000000: '1,400',
      140050000000: '1,401',
      123456780000000: '1,234,568',
    };
    for (final unit in units.entries) {
      for (final amount in amounts.entries) {
        expect(formatTransferFee(amount.key, unit.key),
            '${amount.value}${unit.value}');
      }
    }
  });

  test('keeps small EUR, USD and GBP fees visible and rounds larger units', () {
    const symbols = {
      DisplayCurrency.eur: '€',
      DisplayCurrency.usd: '\$',
      DisplayCurrency.gbp: '£',
    };
    final amounts = {
      0: '0',
      0.05: '0.1',
      0.050001: '0.1',
      0.14: '0.1',
      0.15: '0.2',
      0.3: '0.3',
      0.5: '0.5',
      0.76: '0.8',
      0.94: '0.9',
      0.95: '1',
      0.999999: '1',
      1: '1',
      1.49: '1',
      1.5: '2',
      990: '990',
      8499: '8k',
      8500: '9k',
      1000000: '1m',
      24400000: '24m',
      24500000: '25m',
      24600000: '25m',
      1000000000: '1bn',
      1490000000: '1bn',
      1500000000: '2bn',
      1400000000000: '1,400bn',
      1400500000000: '1,401bn',
    };
    for (final symbol in symbols.entries) {
      for (final amount in [0.000001, 0.01, 0.049999]) {
        expect(formatTransferFee(amount, symbol.key), '<${symbol.value}0.1');
      }
      for (final amount in amounts.entries) {
        expect(formatTransferFee(amount.key, symbol.key),
            '${symbol.value}${amount.value}');
      }
    }
  });
}
