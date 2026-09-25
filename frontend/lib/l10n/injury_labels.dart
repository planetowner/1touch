import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';

String injuryReturnLabel(int? daysUntilReturn, {required Locale locale}) {
  // 현재 부상 명단에 남아 있다면 지난 종료일로 회복을 판단하지 않아요.
  if (daysUntilReturn == null || daysUntilReturn < 0) {
    return translateMessage(locale, 'No return date yet');
  }
  if (daysUntilReturn == 0) {
    return translateMessage(locale, 'Expected back today');
  }
  final key = daysUntilReturn < 7
      ? (daysUntilReturn == 1
          ? 'Expected back in 1 day'
          : 'Expected back in {count} days')
      : (daysUntilReturn == 7
          ? 'Expected back in 1 week'
          : 'Expected back in {count} weeks');
  // 1주 미만은 일수로, 그 이상은 남은 주 수를 올림해 표시해요.
  final count =
      daysUntilReturn < 7 ? daysUntilReturn : (daysUntilReturn / 7).ceil();
  return translateMessage(locale, key, {'count': count});
}
