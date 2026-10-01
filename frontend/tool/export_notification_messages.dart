import 'dart:convert';
import 'dart:io';

import 'package:onetouch/l10n/messages.dart';
import 'package:onetouch/services/notification_message_keys.dart';

// 서버에는 Flutter 런타임이 없어서 배포에 포함할 네 언어 템플릿을 미리 만들어요.
String notificationMessagesJson() {
  final messages = {
    for (final entry in notificationMessageKeys.entries)
      entry.key: {
        for (final language in ['en', 'ko', 'ja', 'zh'])
          language: {
            'title': _translation(entry.value.title, language),
            'body': _translation(entry.value.body, language),
          },
      },
  };
  return '${const JsonEncoder.withIndent('  ').convert({
        '_source': 'frontend/lib/l10n/messages.dart',
        '_generate':
            'cd frontend && dart run tool/export_notification_messages.dart',
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

void main(List<String> arguments) {
  final output = File.fromUri(Platform.script.resolve(
      '../../backend/python/one_touch_loader/core/notification_messages.json'));
  final content = notificationMessagesJson();
  if (arguments.contains('--check')) {
    if (!output.existsSync() || output.readAsStringSync() != content) {
      stderr.writeln(
          '알림 번역 파일을 갱신해 주세요: dart run tool/export_notification_messages.dart');
      exitCode = 1;
    }
    return;
  }
  output.writeAsStringSync(content);
}
