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

const appLocalizationDelegates = GlobalMaterialLocalizations.delegates;

/// 화면 언어만 해석해요. 로그인 추천 지역은 DeviceRegion에서 따로 읽어요.
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

String translateMessage(Locale locale, String message,
    [Map<String, Object> arguments = const {}]) {
  final translations = appMessages[message];
  var translated = switch (locale.languageCode) {
    'ko' => translations?.ko ?? message,
    'ja' => translations?.ja ?? message,
    'zh' => translations?.zh ?? message,
    _ => message,
  };
  for (final entry in arguments.entries) {
    translated = translated.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return translated;
}

// 골키퍼 통계의 Save는 저장 버튼과 뜻이 달라요.
String playerCategoryLabel(BuildContext context, String label) =>
    tr(context, label == 'Save' ? 'Shot stopping' : label);

String teamScreenLabel(BuildContext context, String message) {
  if (Localizations.localeOf(context).languageCode == 'ko') {
    return teamScreenKoreanMessages[message] ?? tr(context, message);
  }
  return tr(context, message);
}
