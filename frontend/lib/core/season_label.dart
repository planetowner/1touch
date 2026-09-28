String compactSeasonLabel(String label) {
  final normalized = label.trim();
  final match = RegExp(r'^(\d{4})\s*/\s*(\d{2}|\d{4})$').firstMatch(normalized);
  if (match == null) return normalized;

  final startYear = match.group(1)!;
  final endYear = match.group(2)!;
  return '${startYear.substring(2)}/${endYear.substring(endYear.length - 2)}';
}
