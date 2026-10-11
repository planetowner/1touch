// 사용자 포인트는 언어와 관계없이 pts로 표시하고 리그 승점 번역과 구분해요.
const pointUnit = 'pts';

String formatDisplayNumber(num value,
    {int decimals = 1, bool trimTrailingZeros = false}) {
  final text = value.toStringAsFixed(decimals);
  return trimTrailingZeros && text.contains('.')
      ? text.replaceFirst(RegExp(r'\.?0+$'), '')
      : text;
}
