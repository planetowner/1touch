import 'package:unorm_dart/unorm_dart.dart' as unorm;

final _accentMarks = RegExp(r'[\u0300-\u036f]');

String normalizeSearchText(String value) {
  // 합쳐진 악센트와 분리 입력된 악센트를 같은 검색어로 비교해요.
  final decomposed = unorm.nfd(value.trim().toLowerCase());
  // 한글 음절과 일본어 탁점은 유지하고, 검색에 쓰는 사본만 바꿔요.
  return unorm.nfc(decomposed.replaceAll(_accentMarks, ''));
}

bool matchesSearchText(String query, Iterable<String?> values) {
  final needle = normalizeSearchText(query);
  return values.any(
      (value) => value != null && normalizeSearchText(value).contains(needle));
}
