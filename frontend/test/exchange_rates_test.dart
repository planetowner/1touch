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
      DisplayCurrency.usd: '\$24.6m',
      DisplayCurrency.gbp: '£18.6m',
      DisplayCurrency.krw: '329.2억 원',
      DisplayCurrency.jpy: '38.9億円',
      DisplayCurrency.cny: '1.6亿元',
    };
    for (final entry in expected.entries) {
      expect(
          formatTransferFee(rates.convertEuros(22000000, entry.key), entry.key),
          entry.value);
    }
  });

  test('keeps KRW, CNY and JPY in hundred millions at every amount', () {
    const units = {
      DisplayCurrency.krw: '억 원',
      DisplayCurrency.cny: '亿元',
      DisplayCurrency.jpy: '億円',
    };
    const amounts = {
      0: '0',
      1000000: '0',
      29931549: '0.3',
      94000000: '0.9',
      96000000: '1',
      100000000: '1',
      150000000: '1.5',
      1000000000: '10',
      6000000000: '60',
      6060000000: '60.6',
      99994000000: '999.9',
      99996000000: '1,000',
      140000000000: '1,400',
      140050000000: '1,400.5',
      123456780000000: '1,234,567.8',
    };
    for (final unit in units.entries) {
      for (final amount in amounts.entries) {
        expect(formatTransferFee(amount.key, unit.key),
            '${amount.value}${unit.value}');
      }
    }
  });

  test('preserves compact formatting for EUR, USD and GBP', () {
    const symbols = {
      DisplayCurrency.eur: '€',
      DisplayCurrency.usd: '\$',
      DisplayCurrency.gbp: '£',
    };
    const amounts = {
      0: '0',
      990: '990',
      8500: '8.5k',
      1000000: '1m',
      24600000: '24.6m',
      1000000000: '1bn',
      1500000000: '1.5bn',
      1400000000000: '1,400bn',
      1400500000000: '1,400.5bn',
    };
    for (final symbol in symbols.entries) {
      for (final amount in amounts.entries) {
        expect(formatTransferFee(amount.key, symbol.key),
            '${symbol.value}${amount.value}');
      }
    }
  });
}
