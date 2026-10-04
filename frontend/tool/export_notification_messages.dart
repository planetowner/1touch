import 'dart:io';

import 'package:onetouch/services/notification_message_keys.dart';

import 'server_message_export.dart';

const _generator = 'tool/export_notification_messages.dart';

String notificationMessagesJson() => serverMessagesJson(
      messageKeys: {
        for (final entry in notificationMessageKeys.entries)
          entry.key: {'title': entry.value.title, 'body': entry.value.body},
      },
      generator: _generator,
    );

void main(List<String> arguments) {
  writeServerMessages(
    output: File.fromUri(Platform.script.resolve(
        '../../backend/python/one_touch_loader/core/notification_messages.json')),
    content: notificationMessagesJson(),
    generator: _generator,
    check: arguments.contains('--check'),
  );
}
