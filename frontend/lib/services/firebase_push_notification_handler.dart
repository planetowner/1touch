import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:onetouch/services/device_notification_service.dart';
import 'package:onetouch/services/notification_message_templates.dart';

typedef PushDestinationHandler = void Function(String destination);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class RemotePushPayload {
  const RemotePushPayload({
    required this.notificationId,
    required this.kind,
    required this.destination,
  });

  final int notificationId;
  final String kind;
  final String destination;

  DeviceNotificationCategory get category {
    if (kind.startsWith('player_')) return DeviceNotificationCategory.player;
    if (kind.startsWith('post_')) return DeviceNotificationCategory.posts;
    return DeviceNotificationCategory.team;
  }

  static RemotePushPayload? fromData(Map<String, dynamic> data) {
    final notificationId = int.tryParse('${data['notification_id'] ?? ''}');
    final kind = '${data['kind'] ?? ''}'.trim();
    final rawDestination = '${data['destination'] ?? ''}'.trim();
    if (notificationId == null || notificationId < 1 || kind.isEmpty) {
      return null;
    }
    final destination = _validatedDestination(rawDestination, kind);
    if (destination == null) return null;
    return RemotePushPayload(
      notificationId: notificationId,
      kind: kind,
      destination: destination,
    );
  }

  static String? _validatedDestination(String value, String kind) {
    final match = RegExp(r'^/match/([1-9][0-9]*)$').firstMatch(value);
    if (match != null) {
      final status = switch (kind) {
        'team_full_time' => 'past',
        'team_match_reminder' ||
        'team_new_bets' ||
        'player_starting_xi' =>
          'upcoming',
        _ => 'live',
      };
      return '$value?status=$status';
    }
    if (RegExp(r'^/notifications/post/[1-9][0-9]*$').hasMatch(value)) {
      return value;
    }
    return null;
  }
}

class FirebasePushNotificationHandler {
  FirebasePushNotificationHandler({
    FirebaseMessaging? messaging,
    DeviceNotificationService? deviceNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _deviceNotifications = deviceNotifications ?? deviceNotificationService;

  final FirebaseMessaging _messaging;
  final DeviceNotificationService _deviceNotifications;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  PushDestinationHandler? _onDestination;
  String? _initialDestination;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> start({required PushDestinationHandler onDestination}) async {
    _onDestination = onDestination;
    if (!_isSupported || _foregroundSubscription != null) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);

    final initialMessage = await _messaging.getInitialMessage();
    _initialDestination = _payload(initialMessage)?.destination;
  }

  String? takeInitialDestination() {
    final destination = _initialDestination;
    _initialDestination = null;
    return destination;
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    try {
      final payload = _payload(message);
      final notification = message.notification;
      final title = notification?.title?.trim();
      final body = notification?.body?.trim();
      if (payload == null ||
          title == null ||
          title.isEmpty ||
          body == null ||
          body.isEmpty) {
        return;
      }
      await _deviceNotifications.showRemote(
        id: payload.notificationId % 2147483647,
        title: title,
        body: body,
        category: payload.category,
        payload: payload.destination,
      );
    } on Object catch (error) {
      debugPrint('Unable to display foreground push notification: $error');
    }
  }

  void _openMessage(RemoteMessage message) {
    final destination = _payload(message)?.destination;
    if (destination != null) _onDestination?.call(destination);
  }

  RemotePushPayload? _payload(RemoteMessage? message) =>
      message == null ? null : RemotePushPayload.fromData(message.data);
}

final firebasePushNotificationHandler = FirebasePushNotificationHandler();
