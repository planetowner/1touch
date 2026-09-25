import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/l10n/injury_labels.dart';

void main() {
  test('uses days below a week and rounds longer periods up to weeks', () {
    const labels = {
      0: 'Expected back today',
      1: 'Expected back in 1 day',
      6: 'Expected back in 6 days',
      7: 'Expected back in 1 week',
      8: 'Expected back in 2 weeks',
      10: 'Expected back in 2 weeks',
      14: 'Expected back in 2 weeks',
      42: 'Expected back in 6 weeks',
    };
    for (final entry in labels.entries) {
      expect(injuryReturnLabel(entry.key, locale: const Locale('en')),
          entry.value);
    }
  });

  test(
      'localizes today, days and singular weeks in Korean, Japanese and Chinese',
      () {
    const cases = [
      (Locale('ko'), 0, '오늘 복귀할 예정이에요'),
      (Locale('ko'), 1, '1일 뒤 복귀할 예정이에요'),
      (Locale('ko'), 6, '6일 뒤 복귀할 예정이에요'),
      (Locale('ko'), 7, '1주 뒤 복귀할 예정이에요'),
      (Locale('ja'), 0, '今日復帰する予定です'),
      (Locale('ja'), 1, '1日後に復帰する予定です'),
      (Locale('ja'), 6, '6日後に復帰する予定です'),
      (Locale('ja'), 7, '1週間後に復帰する予定です'),
      (Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'), 0, '预计今天复出'),
      (
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        1,
        '预计1天后复出'
      ),
      (
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        6,
        '预计6天后复出'
      ),
      (
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        7,
        '预计1周后复出'
      ),
    ];
    for (final (locale, days, expected) in cases) {
      expect(injuryReturnLabel(days, locale: locale), expected);
    }
  });
}
