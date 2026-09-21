import 'package:onetouch/models/fixture_detail.dart';

String playerNumber(double? value, {int decimals = 2}) {
  if (value == null) return '—';
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');
}

String playerMetricValue(FixturePlayerStatMetric metric) {
  if (metric.kind == 'pair') {
    if (metric.numerator == null || metric.denominator == null) return '—';
    return '${playerNumber(metric.numerator)} / ${playerNumber(metric.denominator)}';
  }
  if (metric.value == null) return '—';
  return '${playerNumber(metric.value)}${metric.kind == 'percentage' ? '%' : ''}';
}
