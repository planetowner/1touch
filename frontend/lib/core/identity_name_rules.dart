final _usernamePattern =
    RegExp(r'^(?!\.)(?!.*\.\.)(?!.*\.$)[A-Za-z0-9._]{1,30}$');
final _displayNamePattern = RegExp(r'^[A-Za-z0-9가-힣]+$');

bool _matchesEntire(RegExp pattern, String value) =>
    pattern.matchAsPrefix(value)?.end == value.length;

bool isValidUsername(String value) => _matchesEntire(_usernamePattern, value);

bool isValidDisplayName(String value) {
  if (!_matchesEntire(_displayNamePattern, value)) return false;
  // 한글은 2단위, 영문·숫자는 1단위로 세어 혼합 이름도 같은 길이 규칙을 적용해요.
  final units = value.runes.fold<int>(
    0,
    (total, rune) => total + (rune >= 0xAC00 && rune <= 0xD7A3 ? 2 : 1),
  );
  return units >= 4 && units <= 12;
}

String? usernameValidationMessage(String value) {
  if (value.isEmpty) return 'Enter username';
  if (isValidUsername(value)) return null;
  return 'Use 1–30 English letters, numbers, underscores, or dots. Dots cannot be first, last, or consecutive.';
}

String? displayNameValidationMessage(String value) {
  if (value.isEmpty) return 'Enter nickname';
  if (isValidDisplayName(value)) return null;
  return 'Use Korean syllables, English letters, or numbers only (4–12 units; Korean counts as 2).';
}
