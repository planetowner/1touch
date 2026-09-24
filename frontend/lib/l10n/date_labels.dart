import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/l10n/app_localizations.dart';

String relativeTimeLabel(
  DateTime? publishedAt, {
  required Locale locale,
  DateTime? now,
  Duration? absoluteAfter,
}) {
  if (publishedAt == null) return translateMessage(locale, 'Latest');
  final difference =
      (now ?? DateTime.now()).toUtc().difference(publishedAt.toUtc());
  if (absoluteAfter != null && difference >= absoluteAfter) {
    return DateFormat.MMMd(locale.languageCode).format(publishedAt.toLocal());
  }
  if (difference.inDays >= 1) {
    return translateMessage(
        locale, '{count}d ago', {'count': difference.inDays});
  }
  return _minuteOrHourLabel(difference, locale);
}

String _minuteOrHourLabel(Duration difference, Locale locale) {
  if (difference.inMinutes < 1) return translateMessage(locale, 'Just now');
  final (key, count) = difference.inHours >= 1
      ? ('{count}h ago', difference.inHours)
      : ('{count}m ago', difference.inMinutes);
  return translateMessage(locale, key, {'count': count});
}

// 홈과 팀 화면의 다음 경기 날짜는 같은 형식으로 표시해요.
String fixtureDateLabel(DateTime? kickoff, {required Locale locale}) {
  if (kickoff == null) return translateMessage(locale, 'Date TBD');
  final local = kickoff.toLocal();
  final date = _fixtureDayLabel(local, locale);
  final time = DateFormat.jm(locale.languageCode).format(local);
  return '$date\n$time';
}

String relativeDateLabel(DateTime? date,
    {required Locale locale,
    DateTime? now,
    bool showTimeToday = false,
    String missingDateLabel = 'Date TBD'}) {
  if (date == null) return translateMessage(locale, missingDateLabel);
  final localDate = date.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  // 현지 날짜끼리 비교해 자정과 서머타임에도 오늘·어제를 정확히 구분해요.
  final days = DateTime.utc(localNow.year, localNow.month, localNow.day)
      .difference(DateTime.utc(localDate.year, localDate.month, localDate.day))
      .inDays;
  if (days == 0) {
    // 뉴스·하이라이트는 당일에 분·시간을 쓰고, 지난 경기는 오늘로 표시해요.
    return showTimeToday
        ? _minuteOrHourLabel(localNow.difference(localDate), locale)
        : translateMessage(locale, 'Today');
  }
  if (days == 1) return translateMessage(locale, 'Yesterday');
  if (days < 7) {
    return translateMessage(locale, '{count} days ago', {'count': days});
  }
  // 경기·뉴스·하이라이트는 7일마다 주 수를 늘리고 월·년 단위로 바꾸지 않아요.
  final weeks = days ~/ 7;
  if (weeks == 1) return translateMessage(locale, 'Last week');
  return translateMessage(locale, '{count} weeks ago', {'count': weeks});
}

String _fixtureDayLabel(DateTime local, Locale locale) =>
    locale.languageCode == 'ko'
        ? DateFormat('M월 d일 (E)', 'ko').format(local)
        : DateFormat.MMMEd(locale.languageCode).format(local);

// 경기 헤더의 날짜와 시간은 첨부 디자인처럼 두 줄로 나눠 표시해요.
({String date, String time}) matchKickoffLabels(DateTime? kickoff,
    {required Locale locale}) {
  if (kickoff == null) {
    return (
      date: translateMessage(locale, 'Date TBD'),
      time: translateMessage(locale, 'Time TBD')
    );
  }
  final local = kickoff.toLocal();
  return (
    date: _fixtureDayLabel(
        local, Locale(locale.languageCode == 'ko' ? 'ko' : 'en')),
    time: DateFormat('h:mm a', 'en').format(local),
  );
}
