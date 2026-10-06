import 'package:onetouch/core/number_display.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/player_detail.dart';

String playerNumber(double? value, {int decimals = 1}) {
  if (value == null) return '—';
  return formatDisplayNumber(value,
      decimals: decimals, trimTrailingZeros: true);
}

String playerMetricValue(FixturePlayerStatMetric metric) {
  if (metric.kind == 'pair') {
    if (metric.numerator == null || metric.denominator == null) return '—';
    return '${playerNumber(metric.numerator)} / ${playerNumber(metric.denominator)}';
  }
  if (metric.value == null) {
    return '—';
  }
  return '${playerNumber(metric.value)}${metric.kind == 'percentage' ? '%' : ''}';
}

// 분석과 비교에서 같은 값·단위·이름을 써요. 성공/시도 쌍의 per90은 성공 횟수예요.
({String label, double? value, String text, String unit}) playerSeasonStat(
    PlayerSeasonMetric? stat) {
  final percent = stat?.metric.kind == 'percentage';
  final seasonTotal = switch (stat?.metric.code) {
    'goals' || 'assists' => true,
    _ => false,
  };
  final value = percent || seasonTotal ? stat?.metric.value : stat?.per90;
  final label = switch (stat?.metric.code) {
    'passes' => 'Accurate passes',
    'duels' => 'Duels won',
    _ => stat?.metric.label ?? 'Unavailable',
  };
  return (
    label: label,
    value: value,
    text: '${playerNumber(value)}${percent && value != null ? '%' : ''}',
    unit: percent ? '%' : (seasonTotal ? 'Season total' : 'per 90'),
  );
}
