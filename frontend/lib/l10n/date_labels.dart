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
  return DateFormat.MMMEd(locale.languageCode)
      .add_jm()
      .format(kickoff.toLocal());
}
