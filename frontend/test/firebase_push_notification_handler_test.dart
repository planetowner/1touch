import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/services/firebase_push_notification_handler.dart';
import 'package:onetouch/services/notification_message_templates.dart';

void main() {
  test('maps match notification kinds to the correct match state', () {
    expect(_destination('team_match_reminder'), '/match/42?status=upcoming');
    expect(_destination('player_starting_xi'), '/match/42?status=upcoming');
    expect(_destination('team_goal'), '/match/42?status=live');
    expect(_destination('player_assist'), '/match/42?status=live');
    expect(_destination('team_full_time'), '/match/42?status=past');
  });

  test('accepts community post destinations and maps their category', () {
    final payload = RemotePushPayload.fromData({
      'notification_id': '15',
      'kind': 'post_comment',
      'destination': '/notifications/post/91',
    });

    expect(payload?.destination, '/notifications/post/91');
    expect(payload?.category, DeviceNotificationCategory.posts);
  });

  test('rejects malformed or unsupported destinations', () {
    expect(
      RemotePushPayload.fromData({
        'notification_id': '1',
        'kind': 'team_goal',
        'destination': 'https://example.com',
      }),
      isNull,
    );
    expect(
      RemotePushPayload.fromData({
        'notification_id': 'invalid',
        'kind': 'team_goal',
        'destination': '/match/42',
      }),
      isNull,
    );
  });
}

String? _destination(String kind) => RemotePushPayload.fromData({
      'notification_id': '7',
      'kind': kind,
      'destination': '/match/42',
    })?.destination;
