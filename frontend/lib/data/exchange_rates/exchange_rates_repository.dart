import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/core/display_preferences.dart';

class ExchangeRates {
  ExchangeRates(
      {required this.date, required Map<DisplayCurrency, double> rates})
      : rates = Map.unmodifiable(rates);

  final String date;
  final Map<DisplayCurrency, double> rates;

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    if (json['base'] != 'EUR' || json['amount'] != 1) {
      throw const FormatException('Expected exchange rates for one EUR.');
    }
    final date = json['date'] as String;
    DateTime.parse(date);
    final quotes = json['rates'] as Map<String, dynamic>;
    final rates = <DisplayCurrency, double>{DisplayCurrency.eur: 1};
    for (final currency in DisplayCurrency.values) {
      if (currency == DisplayCurrency.eur) continue;
      final rate = quotes[currency.code];
      if (rate is! num || !rate.isFinite || rate <= 0) {
        throw FormatException('Missing or invalid ${currency.code} rate.');
      }
      rates[currency] = rate.toDouble();
    }
    return ExchangeRates(date: date, rates: rates);
  }

  double convertEuros(num amount, DisplayCurrency currency) =>
      amount * rates[currency]!;
}

class ExchangeRatesRepository {
  ExchangeRatesRepository({required http.Client client}) : _client = client;

  final http.Client _client;
  Future<ExchangeRates>? _latest;
  DateTime? _loadedAt;
  ExchangeRates? _cached;

  ExchangeRates? get cached => _cached;

  // v1은 ECB의 최신 영업일 환율을 제공하고 웹의 교차 출처 조회도 허용해요.
  // https://frankfurter.dev/v1/
  static final _uri = Uri.https('api.frankfurter.dev', '/v1/latest', {
    'base': 'EUR',
    'symbols': DisplayCurrency.values
        .where((currency) => currency != DisplayCurrency.eur)
        .map((currency) => currency.code)
        .join(','),
  });

  Future<ExchangeRates> load() {
    // 목록의 여러 금액이 진행 중인 조회와 1시간 동안의 환율을 함께 써요.
    if (_latest != null &&
        (_loadedAt == null ||
            clock.now().difference(_loadedAt!) < const Duration(hours: 1))) {
      return _latest!;
    }
    _loadedAt = null;
    return _latest = _fetch().then((rates) {
      _cached = rates;
      _loadedAt = clock.now();
      return rates;
    }, onError: (Object error, StackTrace stack) {
      _latest = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<ExchangeRates> _fetch() async {
    final response =
        await _client.get(_uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Exchange rate request failed: ${response.statusCode}', _uri);
    }
    return ExchangeRates.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }
}

// 외부 환율 서비스에는 앱의 로그인 토큰을 보내지 않아요.
final exchangeRatesRepository = ExchangeRatesRepository(client: http.Client());
