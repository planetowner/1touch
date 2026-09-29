import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onetouch/services/notification_message_templates.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationPayloadHandler = void Function(String payload);

class DeviceNotificationService {
  DeviceNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const matchReminderLeadTime = Duration(minutes: 30);

  static const _teamChannel = AndroidNotificationChannel(
    'team_updates',
    'Team updates',
    description: 'Match and score updates for followed teams.',
    importance: Importance.high,
  );
  static const _playerChannel = AndroidNotificationChannel(
    'player_updates',
    'Player updates',
    description: 'Match events for followed players.',
    importance: Importance.high,
  );
  static const _postsChannel = AndroidNotificationChannel(
    'post_updates',
    'Post updates',
    description: 'Reactions and comments on your posts.',
    importance: Importance.high,
  );
  static const _bettingChannel = AndroidNotificationChannel(
    'betting_updates',
    'Betting updates',
    description: 'New bets and settled result updates.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String? _initialPayload;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize({NotificationPayloadHandler? onPayload}) async {
    if (!_isSupported || _initialized) return;
    tz.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_onetouch'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onPayload?.call(payload);
      },
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      for (final channel in const [
        _teamChannel,
        _playerChannel,
        _postsChannel,
        _bettingChannel,
      ]) {
        await android?.createNotificationChannel(channel);
      }
    }
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _initialPayload = launchDetails?.notificationResponse?.payload;
    }
    _initialized = true;
  }

  String? takeInitialPayload() {
    final payload = _initialPayload;
    _initialPayload = null;
    return payload;
  }

  Future<bool> requestPermission() async {
    if (!_isSupported) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
  }

  Future<void> show({
    required int id,
    required DeviceNotificationMessage message,
  }) async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.show(
      id: id,
      title: message.title,
      body: message.body,
      notificationDetails: _details(
        message.type.category,
        body: message.body,
      ),
      payload: message.payload,
    );
  }

  Future<bool> scheduleMatchReminder({
    required int fixtureId,
    required DateTime kickoff,
    required String teamName,
    required Locale locale,
    String? payload,
  }) async {
    if (!_isSupported) return false;
    final reminderAt = kickoff.toUtc().subtract(matchReminderLeadTime);
    if (!reminderAt.isAfter(DateTime.now().toUtc())) return false;
    await initialize();
    final message = NotificationMessageTemplates.build(
      type: NotificationEventType.teamMatchReminder,
      locale: locale,
      data: NotificationTemplateData(team: teamName),
      payload: payload,
    );
    await _plugin.zonedSchedule(
      id: _matchReminderId(fixtureId),
      title: message.title,
      body: message.body,
      scheduledDate: tz.TZDateTime.from(reminderAt, tz.UTC),
      notificationDetails: _details(
        DeviceNotificationCategory.team,
        body: message.body,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
    return true;
  }

  Future<void> cancelMatchReminder(int fixtureId) async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.cancel(id: _matchReminderId(fixtureId));
  }

  NotificationDetails _details(
    DeviceNotificationCategory category, {
    required String body,
  }) {
    final channel = switch (category) {
      DeviceNotificationCategory.team => _teamChannel,
      DeviceNotificationCategory.player => _playerChannel,
      DeviceNotificationCategory.posts => _postsChannel,
      DeviceNotificationCategory.betting => _bettingChannel,
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_onetouch',
        styleInformation: BigTextStyleInformation(body),
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: channel.id,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  int _matchReminderId(int fixtureId) => 100000000 + fixtureId % 100000000;
}

final deviceNotificationService = DeviceNotificationService();
