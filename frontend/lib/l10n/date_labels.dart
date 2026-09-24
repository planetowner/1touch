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
  if (difference.inMinutes < 1) return translateMessage(locale, 'Just now');
  final (key, count) = difference.inDays >= 1
      ? ('{count}d ago', difference.inDays)
      : difference.inHours >= 1
          ? ('{count}h ago', difference.inHours)
          : ('{count}m ago', difference.inMinutes);
  return translateMessage(locale, key, {'count': count});
}

// 홈과 팀 화면의 경기 날짜는 같은 형식으로 표시해요.
String fixtureDateLabel(DateTime? kickoff, {required Locale locale}) {
  if (kickoff == null) return translateMessage(locale, 'Date TBD');
  final local = kickoff.toLocal();
  final date = _fixtureDayLabel(local, locale);
  final time = DateFormat.jm(locale.languageCode).format(local);
  return '$date\n$time';
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
