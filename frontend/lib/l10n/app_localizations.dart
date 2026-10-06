import 'package:onetouch/models/profile_change_limit_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:onetouch/l10n/messages.dart';

export 'package:onetouch/l10n/football_name_labels.dart';

const appSupportedLocales = [
  Locale('en'),
  Locale('ko'),
  Locale('ja'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
];

const _appLocaleEnvironment = String.fromEnvironment('APP_LOCALE');

/// Optional build-time override used for localization testing. An empty value
/// keeps the normal device-language resolution callback in control.
Locale? appLocaleOverride([String value = _appLocaleEnvironment]) {
  final normalized = value.trim().replaceAll('_', '-').toLowerCase();
  if (normalized.isEmpty || normalized == 'system') return null;
  final languageCode = normalized.split('-').first;
  for (final locale in appSupportedLocales) {
    if (locale.languageCode == languageCode) return locale;
  }
  throw FormatException(
    'APP_LOCALE must be system, en, ko, ja, or zh.',
  );
}

const appLocalizationDelegates = GlobalMaterialLocalizations.delegates;

/// 화면 언어만 해석해요. 로그인 추천 국가는 서버가 접속 IP로 판별해요.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return const Locale('en');
}

/// 표시용 문구에만 적용해 API 코드와 사용자가 작성한 내용은 보존해요.
String tr(BuildContext context, String message,
        [Map<String, Object> arguments = const {}]) =>
    translateMessage(Localizations.localeOf(context), message, arguments);

// 대소문자 때문에 번역 키를 나누지 않고 영어 표시만 바꿔요.
String trUpper(BuildContext context, String message) {
  final localized = tr(context, message);
  return Localizations.localeOf(context).languageCode == 'en'
      ? localized.toUpperCase()
      : localized;
}

String profileChangeLimitMessage(
  BuildContext context, {
  required String item,
  required ProfileChangeLimitException limit,
}) {
  final utc = limit.availableAt.toUtc();
  final minute =
      DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  // 초를 숨겨도 실제 해제 시각보다 이르게 안내하지 않도록 다음 분으로 올려요.
  final local =
      (utc.isAfter(minute) ? minute.add(const Duration(minutes: 1)) : minute)
          .toLocal();
  final labels = MaterialLocalizations.of(context);
  final date =
      '${labels.formatFullDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  return tr(
      context,
      'You can change {item} up to {count} times in {days} days. Try again after {date}.',
      {
        'item': item,
        'count': limit.maxChanges,
        'days': limit.windowDays,
        'date': date
      });
}

String translateMessage(Locale locale, String message,
    [Map<String, Object> arguments = const {}]) {
  final translations = appMessages[message];
  final translated = switch (locale.languageCode) {
    'ko' => translations?.ko ?? message,
    'ja' => translations?.ja ?? message,
    'zh' => translations?.zh ?? message,
    _ => message,
  };
  // 삽입한 닉네임·댓글의 중괄호를 다른 번역 인자로 다시 치환하지 않아요.
  return translated.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (match) => '${arguments[match[1]] ?? match[0]}',
  );
}

// 골키퍼 통계의 Save는 저장 버튼과 뜻이 달라요.
String playerCategoryLabel(BuildContext context, String label) =>
    tr(context, label == 'Save' ? 'Shot stopping' : label);

String trTitle(BuildContext context, String label) {
  final localized = tr(context, label);
  if (Localizations.localeOf(context).languageCode != 'en') return localized;
  const minorWords = {
    'a',
    'an',
    'and',
    'at',
    'by',
    'for',
    'from',
    'in',
    'of',
    'on',
    'or',
    'per',
    'the',
    'to',
    'with',
  };
  var wordIndex = 0;
  return localized.replaceAllMapped(RegExp(r'[A-Za-z]+'), (match) {
    final word = match.group(0)!;
    final lower = word.toLowerCase();
    final isFirstWord = wordIndex++ == 0;
    final hasIntentionalCapital =
        word.length > 1 && word.substring(1).contains(RegExp(r'[A-Z]'));
    if (word == word.toUpperCase() || hasIntentionalCapital) return word;
    if (!isFirstWord && minorWords.contains(lower)) return lower;
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  });
}

String appStatLabel(BuildContext context, String label) =>
    trTitle(context, label);

String playerMetricLabel(BuildContext context, String label) =>
    appStatLabel(context, label);

String teamScreenLabel(BuildContext context, String message) =>
    _koreanContextLabel(context, message, teamScreenKoreanMessages);

String playerTabLabel(BuildContext context, String message) =>
    _koreanContextLabel(context, message, playerTabKoreanMessages);

String _koreanContextLabel(
    BuildContext context, String message, Map<String, String> messages) {
  if (Localizations.localeOf(context).languageCode == 'ko') {
    return messages[message] ?? tr(context, message);
  }
  return tr(context, message);
}
