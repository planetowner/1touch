import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/identity_name_rules.dart';

void main() {
  test('username accepts underscores anywhere and dots only inside', () {
    for (final name in [
      'june.kim',
      'june_kim',
      '_junekim',
      'junekim_',
      'june__kim',
      '_',
      'a',
      'a'.padRight(30, 'a'),
    ]) {
      expect(isValidUsername(name), isTrue, reason: name);
    }
    for (final name in [
      '',
      '.junekim',
      'junekim.',
      'june..kim',
      'june-kim',
      'june kim',
      '한글',
      'éclair',
      'june@kim',
      'a'.padRight(31, 'a'),
      ' june',
      'june ',
      'june\n',
    ]) {
      expect(isValidUsername(name), isFalse, reason: name);
    }
  });

  test('nickname counts Korean syllables as two units', () {
    for (final name in [
      '메시',
      '정미르',
      'Maple',
      'June123',
      '1234',
      '메이플123',
      '가a1',
      'a'.padRight(12, 'a'),
      '가'.padRight(6, '가'),
    ]) {
      expect(isValidDisplayName(name), isTrue, reason: name);
    }
    for (final name in [
      '',
      'June_Kim',
      'June.Kim',
      'June-Kim',
      'June Kim',
      '정미르♡',
      'ㅋㅋ메이플',
      '메',
      'abc',
      '가'.padRight(7, '가'),
      'a'.padRight(13, 'a'),
      '가가${'a'.padRight(9, 'a')}',
      '가a',
      '닉네임 ',
      'Maple\n',
    ]) {
      expect(isValidDisplayName(name), isFalse, reason: name);
    }
  });
}
