import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/notifications/api/api_notification_preferences_repository.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository.dart';

final NotificationPreferencesRepository notificationPreferencesRepository =
    ApiNotificationPreferencesRepository(api: apiClient);
