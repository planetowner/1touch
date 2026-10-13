import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/services/device_notification_service.dart';
import 'package:onetouch/services/notification_message_templates.dart';
import 'package:onetouch/services/notification_message_keys.dart';

import '../tool/export_notification_messages.dart' as exporter;

void main() {
  test(
      'server export and app use the same four-language notification templates',
      () {
    final generated = File(
            '../backend/python/one_touch_loader/core/notification_messages.json')
        .readAsStringSync();
    expect(generated, exporter.notificationMessagesJson(),
        reason: 'Run dart run tool/export_notification_messages.dart');
    final templates = (jsonDecode(generated)
        as Map<String, dynamic>)['messages'] as Map<String, dynamic>;
    expect(NotificationEventType.values.map((type) => type.kind).toSet(),
        notificationMessageKeys.keys.toSet()..remove('team_goal_against'));
    for (final type in NotificationEventType.values) {
      for (final language in ['en', 'ko', 'ja', 'zh']) {
        final message = NotificationMessageTemplates.build(
          type: type,
          locale: Locale(language),
          data: const NotificationTemplateData(
              homeTeam: 'Home',
              awayTeam: 'Away',
              player: 'Player',
              team: 'Team',
              displayName: 'User'),
        );
        expect(
            message.title,
            (templates[type.kind][language]['title'] as String)
                .replaceAll('{team}', 'Team')
                .replaceAll('{player}', 'Player'));
        expect(message.body, isNot(contains(RegExp(r'\{\w+\}'))));
        expect(message.body, isNotEmpty);
      }
    }
  });

  test('Japanese and Chinese push copy is localized', () {
    for (final entry
        in {'ja': 'Away戦にスタメン出場します。', 'zh': '对阵Away首发出场。'}.entries) {
      final message = NotificationMessageTemplates.build(
        type: NotificationEventType.playerStartingXi,
        locale: Locale(entry.key),
        data: const NotificationTemplateData(player: 'Son', opponent: 'Away'),
      );
      expect(message.body, entry.value);
    }
  });

  test('contains iOS and Android rows except spreadsheet rows 1, 17, and 19',
      () {
    expect(NotificationEventType.values, hasLength(16));
    final rows =
        NotificationEventType.values.map((type) => type.spreadsheetNumber);
    expect(rows, isNot(contains(1)));
    expect(rows, isNot(contains(17)));
    expect(rows, isNot(contains(19)));
    expect(
      NotificationEventType.teamMatchReminder.deliveryTiming,
      NotificationDeliveryTiming.thirtyMinutesBeforeKickoff,
    );
    expect(
      NotificationEventType.values
          .where((type) =>
              type.deliveryTiming == NotificationDeliveryTiming.eventDriven)
          .length,
      15,
    );
  });

  test('match reminders use the approved 30-minute schedule and copy', () {
    final message = NotificationMessageTemplates.build(
      type: NotificationEventType.teamMatchReminder,
      locale: const Locale('en'),
      data: const NotificationTemplateData(
          team: 'FC Barcelona', opponent: 'Real Madrid'),
    );

    expect(DeviceNotificationService.matchReminderLeadTime,
        const Duration(minutes: 30));
    expect(message.title, 'FC Barcelona');
    expect(message.body, 'Kickoff vs Real Madrid in 30 min.');
  });

  test('Korean and English event messages use their respective templates', () {
    const data = NotificationTemplateData(
      player: 'Heungmin Son',
      team: 'Tottenham',
      minute: '72',
      homeTeam: 'Tottenham',
      awayTeam: 'Arsenal',
      score: '1-0',
    );

    final korean = NotificationMessageTemplates.build(
      type: NotificationEventType.playerGoal,
      locale: const Locale('ko'),
      data: data,
    );
    final english = NotificationMessageTemplates.build(
      type: NotificationEventType.playerGoal,
      locale: const Locale('en'),
      data: data,
    );

    expect(korean.title, 'Heungmin Son');
    expect(korean.body, '⚽ 골! 72’ · Tottenham 1-0 Arsenal');
    expect(english.title, 'Heungmin Son');
    expect(english.body, '⚽ Goal! 72’ · Tottenham 1-0 Arsenal');
  });

  test('conceded copy uses the same goal event in all four languages', () {
    for (final entry
        in {'en': 'Conceded', 'ko': '실점', 'ja': '失点', 'zh': '失球'}.entries) {
      final message = NotificationMessageTemplates.build(
        type: NotificationEventType.teamGoal,
        locale: Locale(entry.key),
        data: const NotificationTemplateData(
          team: 'Away',
          homeTeam: 'Home',
          awayTeam: 'Away',
          player: 'Player',
          minute: '45+2',
          score: '1-0',
          goalAgainst: true,
        ),
      );
      expect(message.type, NotificationEventType.teamGoal);
      expect(message.title, 'Away');
      expect(message.body, '${entry.value} · Player 45+2’ · Home 1-0 Away');
    }
  });

  test('notification arguments preserve braces in user content', () {
    final message = NotificationMessageTemplates.build(
      type: NotificationEventType.postComment,
      locale: const Locale('ja'),
      data: const NotificationTemplateData(
        displayName: '{minute}',
        commentPreview: 'Keep {score} as text',
        score: '3-1',
        minute: '90',
      ),
    );
    expect(message.body, '{minute}: Keep {score} as text');
  });

  test('comment previews are limited to 60 characters', () {
    final message = NotificationMessageTemplates.build(
      type: NotificationEventType.postComment,
      locale: const Locale('en'),
      data: NotificationTemplateData(
        displayName: 'colin',
        commentPreview: List.filled(61, 'a').join(),
      ),
    );

    expect(message.body, 'colin: ${List.filled(60, 'a').join()}…');
  });
}
