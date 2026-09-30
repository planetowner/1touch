import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/notifications/api/api_notification_inbox_repository.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository.dart';

final NotificationInboxRepository notificationInboxRepository =
    ApiNotificationInboxRepository(api: apiClient);
