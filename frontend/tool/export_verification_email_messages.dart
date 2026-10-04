import 'dart:io';

import 'server_message_export.dart';

const _generator = 'tool/export_verification_email_messages.dart';

String verificationEmailMessagesJson() => serverMessagesJson(
      messageKeys: const {
        'verification': {
          'title': 'Email Verification Code',
          'code_label': 'Your 1touch code is',
          'signup':
              'To continue signing up, enter this code within {minutes} minutes.',
          'password_reset':
              'To reset your password, enter this code within {minutes} minutes.',
          'username_recovery':
              'To find your username, enter this code within {minutes} minutes.',
          'email_change':
              'To change your email address, enter this code within {minutes} minutes.',
          'ignore':
              "If you didn't request this verification code, you can ignore this email.",
        },
      },
      generator: _generator,
    );

void main(List<String> arguments) {
  writeServerMessages(
    output: File.fromUri(Platform.script.resolve(
        '../../backend/python/one_touch_loader/api/services/email_templates/messages.json')),
    content: verificationEmailMessagesJson(),
    generator: _generator,
    check: arguments.contains('--check'),
  );
}
