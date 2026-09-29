import 'package:onetouch/data/notifications/local/local_notification_preferences_repository.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository.dart';

// Swap this provider to an API implementation when the backend endpoint exists.
final NotificationPreferencesRepository notificationPreferencesRepository =
    LocalNotificationPreferencesRepository();
