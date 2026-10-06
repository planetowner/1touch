String formatDisplayNumber(num value,
    {int decimals = 1, bool trimTrailingZeros = false}) {
  final text = value.toStringAsFixed(decimals);
  return trimTrailingZeros && text.contains('.')
      ? text.replaceFirst(RegExp(r'\.?0+$'), '')
      : text;
}
