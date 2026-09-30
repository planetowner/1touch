import 'package:onetouch/data/notifications/notification_preferences.dart';

/// Stores the user's notification choices independently of the UI.
///
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

  Future<void> applyNewBetsToAll(
    Iterable<int> teamIds,
    bool enabled,
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
