import 'package:onetouch/data/notifications/notification_preferences.dart';

/// Stores the user's notification choices independently of the UI.
///
/// Replace the local provider implementation with an API implementation when
/// notification preference endpoints become available.
abstract interface class NotificationPreferencesRepository {
  Future<NotificationPreferenceSnapshot> load();

  Future<void> saveGlobal(GlobalNotificationPreferences preferences);

  Future<void> saveTeam(
    int teamId,
    TeamNotificationPreferences preferences,
  );

  Future<void> applyTeamToAll(
    Iterable<int> teamIds,
    TeamNotificationPreferences preferences,
  );

  Future<void> savePlayer(
    int playerId,
    PlayerNotificationPreferences preferences,
  );

  Future<void> applyPlayerToAll(
    Iterable<int> playerIds,
    PlayerNotificationPreferences preferences,
  );
}
