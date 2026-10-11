import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/core/display_preferences.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/exchange_rates/exchange_rates_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';

Text transferValueText(String value, {Key? key}) => Text(
      value,
      key: key,
      style: Body1_b.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    );

String formatTransferFee(num amount, DisplayCurrency currency) {
  final fixedUnit = switch (currency) {
    DisplayCurrency.krw => '억 원',
    DisplayCurrency.cny => '亿元',
    DisplayCurrency.jpy => '億円',
    DisplayCurrency.usd || DisplayCurrency.eur || DisplayCurrency.gbp => null,
  };
  // 원·위안·엔은 금액이 작아도 억 단위를 유지해 이적료를 같은 기준으로 비교해요.
  if (fixedUnit != null) {
    return '${_formatScaledFee(amount, 100000000)}$fixedUnit';
  }

  final rounded = amount.round();
  for (final (divisor, suffix) in [
    (1000000000, 'bn'),
    (1000000, 'm'),
    (1000, 'k'),
  ]) {
    if (rounded >= divisor) {
      return '${currency.symbol}${_formatScaledFee(rounded, divisor)}$suffix';
    }
  }
  return '${currency.symbol}$rounded';
}

// 화면 언어와 관계없이 천 단위 쉼표와 소수점 한 자리 표기를 함께 적용해요.
final _feeNumberFormat = NumberFormat('#,##0.#', 'en_US');

String _formatScaledFee(num amount, int divisor) =>
    _feeNumberFormat.format(amount / divisor);

class TransferFee extends StatefulWidget {
  const TransferFee({
    super.key,
    required this.amountInEuros,
    this.repository,
    this.textKey,
  });

  // 손흥민 22m·케인 100m·그리즈만 120m의 원본 금액을 기사와 대조해 EUR 기준을 유지해요.
  // https://www.mk.co.kr/en/sports/11388958
  // https://www.fcbarcelona.com/en/news/1277948/barca-sign-antoine-griezmann
  final int amountInEuros;
  final ExchangeRatesRepository? repository;
  final Key? textKey;

  @override
  State<TransferFee> createState() => _TransferFeeState();
}

class _TransferFeeState extends State<TransferFee> {
  Widget _text(String value) => transferValueText(value, key: widget.textKey);

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<DisplayPreferences>(
        valueListenable: appDisplayPreferences,
        builder: (context, preferences, _) {
          final currency = preferences.currency;
          if (currency == DisplayCurrency.eur) {
            return _text(formatTransferFee(widget.amountInEuros, currency));
          }
          final repository = widget.repository ?? exchangeRatesRepository;
          return FutureBuilder<ExchangeRates>(
            future: repository.load(),
            initialData: repository.cached,
            builder: (context, snapshot) {
              // 갱신 중이거나 갱신에 실패해도 마지막 환율과 기준 날짜로 금액을 바로 보여줘요.
              final rates = snapshot.data ?? repository.cached;
              if (rates != null) {
                return Tooltip(
                  message: tr(context, 'ECB exchange rate · {date}',
                      {'date': rates.date}),
                  child: _text(formatTransferFee(
                    rates.convertEuros(widget.amountInEuros, currency),
                    currency,
                  )),
                );
              }
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasError) {
                final message =
                    tr(context, 'Unable to load exchange rates. Tap to retry.');
                return Tooltip(
                  message: message,
                  child: InkWell(
                    onTap: () => setState(() {}),
                    child: Semantics(
                        button: true, label: message, child: _text('—')),
                  ),
                );
              }
              return _text('…');
            },
          );
        },
      );
}
