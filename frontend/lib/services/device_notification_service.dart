import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onetouch/services/notification_message_templates.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationPayloadHandler = void Function(String payload);

class DeviceNotificationService {
  DeviceNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const matchReminderLeadTime = Duration(minutes: 30);

  AndroidNotificationChannel get _teamChannel => AndroidNotificationChannel(
        'team_updates',
        translateMessage(appLocaleController.value, 'Team updates'),
        description: translateMessage(appLocaleController.value,
            'Match and score updates for followed teams.'),
        importance: Importance.high,
      );
  AndroidNotificationChannel get _playerChannel => AndroidNotificationChannel(
        'player_updates',
        translateMessage(appLocaleController.value, 'Player updates'),
        description: translateMessage(
            appLocaleController.value, 'Match events for followed players.'),
        importance: Importance.high,
      );
  AndroidNotificationChannel get _postsChannel => AndroidNotificationChannel(
        'post_updates',
        translateMessage(appLocaleController.value, 'Post updates'),
        description: translateMessage(
            appLocaleController.value, 'Reactions and comments on your posts.'),
        importance: Importance.high,
      );
  AndroidNotificationChannel get _bettingChannel => AndroidNotificationChannel(
        'betting_updates',
        translateMessage(appLocaleController.value, 'Betting updates'),
        description: translateMessage(
            appLocaleController.value, 'New bets and settled result updates.'),
        importance: Importance.high,
      );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  String? _initialPayload;
  NotificationPayloadHandler? _onPayload;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize({NotificationPayloadHandler? onPayload}) async {
    if (onPayload != null) _onPayload = onPayload;
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
        if (payload != null && payload.isNotEmpty) _onPayload?.call(payload);
      },
    );
    await _updateChannels();
    appLocaleController.addListener(_handleLocaleChanged);
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _initialPayload = launchDetails?.notificationResponse?.payload;
    }
    _initialized = true;
  }

  // 알림 설정 화면의 채널 이름도 앱에서 고른 언어를 따라가요.
  void _handleLocaleChanged() => unawaited(_updateChannels());

  Future<void> _updateChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      for (final channel in [
        _teamChannel,
        _playerChannel,
        _postsChannel,
        _bettingChannel,
      ]) {
        await android?.createNotificationChannel(channel);
      }
    } on Object catch (error) {
      debugPrint('Unable to update notification channels: $error');
    }
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

  Future<void> showRemote({
    required int id,
    required String title,
    required String body,
    required DeviceNotificationCategory category,
    required String payload,
  }) async {
    if (!_isSupported) return;
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(category, body: body),
      payload: payload,
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
      data: NotificationTemplateData(
        team: teamName,
        minutesUntilKickoff: matchReminderLeadTime.inMinutes,
      ),
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
