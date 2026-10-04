import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/export_verification_email_messages.dart' as exporter;

void main() {
  test('email translations shipped to the server match messages.dart', () {
    final generated = File(
            '../backend/python/one_touch_loader/api/services/email_templates/messages.json')
        .readAsStringSync();
    expect(generated, exporter.verificationEmailMessagesJson(),
        reason: 'Run dart run tool/export_verification_email_messages.dart');
    final copy = (jsonDecode(generated) as Map<String, dynamic>)['messages']
        ['verification'] as Map;
    expect(copy.keys, unorderedEquals(['en', 'ko', 'ja', 'zh']));
    for (final language in copy.values) {
      for (final purpose in [
        'signup',
        'password_reset',
        'username_recovery',
        'email_change'
      ]) {
        expect(language[purpose], contains('{minutes}'));
      }
    }
  });
}
