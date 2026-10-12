const usernameGuideMessage =
    'Use 1–30 characters with English letters, numbers, _ or .';
const displayNameGuideMessage =
    'Use 4–12 characters with Korean syllables, English letters, or numbers. Korean syllables count as 2.';
const usernameTakenMessage = 'That ID is already taken. Try another one.';
const displayNameTakenMessage =
    'That nickname is already taken. Try another one.';

final _usernamePattern = RegExp(r'^[A-Za-z0-9._]+$');
final _displayNamePattern = RegExp(r'^[A-Za-z0-9가-힣]+$');
final _koreanJamoPattern = RegExp(
    r'[\u1100-\u11FF\u3131-\u318E\uA960-\uA97F\uD7B0-\uD7FF\uFFA0-\uFFDC]');

bool _matchesEntire(RegExp pattern, String value) =>
    pattern.matchAsPrefix(value)?.end == value.length;

bool isValidUsername(String value) => usernameValidationMessage(value) == null;

bool isValidDisplayName(String value) =>
    displayNameValidationMessage(value) == null;

String? usernameValidationMessage(String value) {
  if (value.isEmpty) return 'Enter your ID.';
  // 여러 조건을 어겨도 문자, 길이, 점 위치 순서로 하나만 안내해요.
  if (!_matchesEntire(_usernamePattern, value)) {
    return 'Use only English letters, numbers, _ or .';
  }
  if (value.length > 30) return 'Use 1–30 characters.';
  if (value.startsWith('.') || value.endsWith('.') || value.contains('..')) {
    return "Periods can't be first, last, or consecutive.";
  }
  return null;
}

String? displayNameValidationMessage(String value) {
  if (value.isEmpty) return 'Enter your nickname.';
  if (!_matchesEntire(_displayNamePattern, value)) {
    // 허용되지 않는 한글 자모는 일반 문자 오류보다 구체적으로 안내해요.
    return _koreanJamoPattern.hasMatch(value)
        ? 'Use complete Korean syllables, like 가.'
        : 'Use only Korean syllables, English letters, and numbers.';
  }
  // 한글은 2단위, 영문·숫자는 1단위로 세어 혼합 이름도 같은 길이 규칙을 적용해요.
  final units = value.runes.fold<int>(
    0,
    (total, rune) => total + (rune >= 0xAC00 && rune <= 0xD7A3 ? 2 : 1),
  );
  return units >= 4 && units <= 12
      ? null
      : 'Use 4–12 characters. Korean syllables count as 2 each.';
}
