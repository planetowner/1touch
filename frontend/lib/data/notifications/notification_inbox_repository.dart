import 'package:onetouch/data/notifications/notification_inbox.dart';

abstract interface class NotificationInboxRepository {
  Future<NotificationInboxPageData> load({
    int? beforeId,
    int limit = 30,
    int? teamId,
  });

  Future<void> markReadThrough(int notificationId);
}
