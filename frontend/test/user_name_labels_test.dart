import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/l10n/user_name_labels.dart';

void main() {
  test('formats names in the order and spacing of the app language', () {
    for (final (locale, firstName, lastName, expected) in [
      (const Locale('en'), 'John', 'Doe', 'John Doe'),
      (const Locale('ko'), '길동', '홍', '홍길동'),
      (const Locale('ja'), '太郎', '山田', '山田太郎'),
      (
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        '小明',
        '王',
        '王小明'
      ),
    ]) {
      expect(
        userNameLabel(locale: locale, firstName: firstName, lastName: lastName),
        expected,
      );
    }
  });

  test('uses the app language without guessing from name characters', () {
    expect(
        userNameLabel(
            locale: const Locale('ko'), firstName: 'John', lastName: 'Doe'),
        'DoeJohn');
    expect(
        userNameLabel(
            locale: const Locale('en'), firstName: '길동', lastName: '홍'),
        '길동 홍');
  });
}
