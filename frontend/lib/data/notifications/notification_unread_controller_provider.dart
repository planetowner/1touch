import 'dart:async';

import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository_provider.dart';
import 'package:onetouch/data/notifications/notification_unread_controller.dart';

final NotificationUnreadController notificationUnreadController =
    _createNotificationUnreadController();

NotificationUnreadController _createNotificationUnreadController() {
  final controller =
      NotificationUnreadController(repository: notificationInboxRepository);
  var token = authSession.accessToken;
  authSession.addListener(() {
    if (token == authSession.accessToken) return;
    token = authSession.accessToken;
    controller.clear();
    if (token != null) unawaited(controller.refresh());
  });
  return controller;
}
