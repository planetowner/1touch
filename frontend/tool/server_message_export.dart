import 'dart:convert';
import 'dart:io';

import 'package:onetouch/l10n/messages.dart';

// 서버에는 Dart 런타임이 없어서 알림과 메일 번역을 같은 규칙으로 내보내요.
String serverMessagesJson({
  required Map<String, Map<String, String>> messageKeys,
  required String generator,
}) {
  final messages = {
    for (final entry in messageKeys.entries)
      entry.key: {
        for (final language in ['en', 'ko', 'ja', 'zh'])
          language: {
            for (final field in entry.value.entries)
              field.key: _translation(field.value, language),
          },
      },
  };
  return '${const JsonEncoder.withIndent('  ').convert({
        '_source': 'frontend/lib/l10n/messages.dart',
        '_generate': 'cd frontend && dart run $generator',
        'messages': messages,
      })}\n';
}

String _translation(String key, String language) {
  final translations = appMessages[key]!;
  return switch (language) {
    'ko' => translations.ko,
    'ja' => translations.ja,
    'zh' => translations.zh,
    _ => key,
  };
}

void writeServerMessages({
  required File output,
  required String content,
  required String generator,
  required bool check,
}) {
  if (check) {
    if (!output.existsSync() || output.readAsStringSync() != content) {
      stderr.writeln('서버 번역 파일을 갱신해 주세요: dart run $generator');
      exitCode = 1;
    }
    return;
  }
  output.writeAsStringSync(content);
}
