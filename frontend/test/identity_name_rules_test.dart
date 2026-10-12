import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/identity_name_rules.dart';

void main() {
  test('username reports required, character, length, and period errors', () {
    for (final entry in <String, String?>{
      '': 'Enter your ID.',
      'abc!': 'Use only English letters, numbers, _ or .',
      'abc\n': 'Use only English letters, numbers, _ or .',
      '가나다': 'Use only English letters, numbers, _ or .',
      'a'.padRight(31, 'a'): 'Use 1–30 characters.',
      '.member': "Periods can't be first, last, or consecutive.",
      'member.': "Periods can't be first, last, or consecutive.",
      'mem..ber': "Periods can't be first, last, or consecutive.",
      '.': "Periods can't be first, last, or consecutive.",
      '!'.padRight(31, '.'): 'Use only English letters, numbers, _ or .',
      '.'.padRight(31, 'a'): 'Use 1–30 characters.',
      '_': null,
      'a'.padRight(30, 'a'): null,
      'Ab9_.c': null,
    }.entries) {
      expect(usernameValidationMessage(entry.key), entry.value,
          reason: entry.key);
      expect(isValidUsername(entry.key), entry.value == null,
          reason: entry.key);
    }
  });

  test('nickname distinguishes incomplete Korean and weighted length errors',
      () {
    for (final entry in <String, String?>{
      '': 'Enter your nickname.',
      'nick_name': 'Use only Korean syllables, English letters, and numbers.',
      'ab c': 'Use only Korean syllables, English letters, and numbers.',
      'abc\n': 'Use only Korean syllables, English letters, and numbers.',
      '😀abc': 'Use only Korean syllables, English letters, and numbers.',
      'ㄱ': 'Use complete Korean syllables, like 가.',
      'ㅏ': 'Use complete Korean syllables, like 가.',
      'ㅋㅋ': 'Use complete Korean syllables, like 가.',
      '가나ㄱ': 'Use complete Korean syllables, like 가.',
      '\u1100\u1161': 'Use complete Korean syllables, like 가.',
      'ㅋㅋ!': 'Use complete Korean syllables, like 가.',
      'abc': 'Use 4–12 characters. Korean syllables count as 2 each.',
      '가a': 'Use 4–12 characters. Korean syllables count as 2 each.',
      '가가가가가가a': 'Use 4–12 characters. Korean syllables count as 2 each.',
      '가가가가가가가': 'Use 4–12 characters. Korean syllables count as 2 each.',
      'a'.padRight(13, 'a'):
          'Use 4–12 characters. Korean syllables count as 2 each.',
      '가a1': null,
      '가가': null,
      '가가가가가가': null,
      '가가가가가ab': null,
      'abcd': null,
      'a'.padRight(12, 'a'): null,
    }.entries) {
      expect(displayNameValidationMessage(entry.key), entry.value,
          reason: entry.key);
      expect(isValidDisplayName(entry.key), entry.value == null,
          reason: entry.key);
    }
  });

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
