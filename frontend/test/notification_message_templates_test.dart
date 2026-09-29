import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/services/device_notification_service.dart';
import 'package:onetouch/services/notification_message_templates.dart';

void main() {
  test('contains iOS and Android rows except spreadsheet rows 1 and 17', () {
    expect(NotificationEventType.values, hasLength(17));
    final rows =
        NotificationEventType.values.map((type) => type.spreadsheetNumber);
    expect(rows, isNot(contains(1)));
    expect(rows, isNot(contains(17)));
    expect(
      NotificationEventType.teamMatchReminder.deliveryTiming,
      NotificationDeliveryTiming.thirtyMinutesBeforeKickoff,
    );
    expect(
      NotificationEventType.values
          .where((type) =>
              type.deliveryTiming == NotificationDeliveryTiming.eventDriven)
          .length,
      16,
    );
  });

  test('match reminders use the approved 30-minute schedule and copy', () {
    final message = NotificationMessageTemplates.build(
      type: NotificationEventType.teamMatchReminder,
      locale: const Locale('en'),
      data: const NotificationTemplateData(team: 'FC Barcelona'),
    );

    expect(DeviceNotificationService.matchReminderLeadTime,
        const Duration(minutes: 30));
    expect(message.body, 'FC Barcelona kicks off in 30 minutes.');
  });

  test('Korean and English event messages use their respective templates', () {
    const data = NotificationTemplateData(
      player: 'Heungmin Son',
      team: 'Tottenham',
      minute: '72',
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

    expect(korean.body, "⚽ Heungmin Son 골! 72' (Tottenham)");
    expect(english.body, "⚽ Heungmin Son scores! 72' (Tottenham)");
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
