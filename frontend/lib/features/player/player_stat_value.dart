import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/player_detail.dart';

String playerNumber(double? value, {int decimals = 2}) {
  if (value == null) return '—';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');
}

String playerMetricValue(FixturePlayerStatMetric metric,
    {bool zeroForMissingCount = false}) {
  if (metric.kind == 'pair') {
    if (metric.numerator == null || metric.denominator == null) return '—';
    return '${playerNumber(metric.numerator)} / ${playerNumber(metric.denominator)}';
  }
  if (metric.value == null) {
    return zeroForMissingCount && metric.kind == 'count' ? '0' : '—';
  }
  return '${playerNumber(metric.value)}${metric.kind == 'percentage' ? '%' : ''}';
}

// 분석과 비교에서 같은 값·단위·이름을 써요. 성공/시도 쌍의 per90은 성공 횟수예요.
({String label, double? value, String text, String unit}) playerSeasonStat(
    PlayerSeasonMetric? stat) {
  final percent = stat?.metric.kind == 'percentage';
  final value = percent ? stat?.metric.value : stat?.per90;
  final label = switch (stat?.metric.code) {
    'passes' => 'Accurate passes',
    'duels' => 'Duels won',
    _ => stat?.metric.label ?? 'Unavailable',
  };
  return (
    label: label,
    value: value,
    text: '${playerNumber(value)}${percent && value != null ? '%' : ''}',
    unit: percent ? '%' : 'per 90',
  );
}
