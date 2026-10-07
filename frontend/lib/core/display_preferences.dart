import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MeasurementUnit {
  metric('Metric (cm)'),
  imperial('Imperial (ft/in)');

  const MeasurementUnit(this.label);
  final String label;

  String formatHeight(int? centimeters) {
    if (centimeters == null) return '—';
    if (this == metric) return '${centimeters}cm';
    // 전체 인치를 먼저 반올림해 5ft 12in처럼 표시되지 않게 해요.
    final inches = (centimeters / 2.54).round();
    return '${inches ~/ 12}ft ${inches % 12}in';
  }

  String formatWeight(int? kilograms) {
    if (kilograms == null) return '—';
    if (this == metric) return '${kilograms}kg';
    return '${(kilograms / 0.45359237).round()}lb';
  }
}

enum DisplayCurrency {
  usd('USD', '\$'),
  eur('EUR', '€'),
  gbp('GBP', '£'),
  krw('KRW', '₩'),
  jpy('JPY', '¥');

  const DisplayCurrency(this.code, this.symbol);
  final String code;
  final String symbol;
  String get label => '$code ($symbol)';
}

@immutable
class DisplayPreferences {
  const DisplayPreferences({
    this.unit = MeasurementUnit.metric,
    this.currency = DisplayCurrency.usd,
  });

  final MeasurementUnit unit;
  final DisplayCurrency currency;
}

class DisplayPreferencesController extends ValueNotifier<DisplayPreferences> {
  DisplayPreferencesController() : super(const DisplayPreferences());

  static const _storageKey = 'app.display_preferences';

  Future<void> initialize() async {
    final storage = await SharedPreferences.getInstance();
    final saved = storage.getString(_storageKey);
    if (saved == null) {
      value = const DisplayPreferences();
      return;
    }
    final json = jsonDecode(saved) as Map<String, dynamic>;
    value = DisplayPreferences(
      unit: MeasurementUnit.values.byName(json['unit'] as String),
      currency: DisplayCurrency.values.byName(json['currency'] as String),
    );
  }

  Future<void> save(DisplayPreferences preferences) async {
    final storage = await SharedPreferences.getInstance();
    // 두 설정을 함께 저장한 뒤 알려야 화면과 저장값이 일치해요.
    final saved = await storage.setString(
      _storageKey,
      jsonEncode({
        'unit': preferences.unit.name,
        'currency': preferences.currency.name,
      }),
    );
    if (!saved) throw StateError('Unable to save display preferences.');
    value = preferences;
  }
}

final appDisplayPreferences = DisplayPreferencesController();
