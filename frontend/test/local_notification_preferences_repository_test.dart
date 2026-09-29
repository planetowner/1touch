import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/notifications/local/local_notification_preferences_repository.dart';
import 'package:onetouch/data/notifications/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returns approved defaults when no preferences were saved', () async {
    final repository = LocalNotificationPreferencesRepository();

    final snapshot = await repository.load();

    expect(snapshot.global.postReactions, isTrue);
    expect(snapshot.team(83).matchReminder, isFalse);
    expect(snapshot.team(83).goal, isTrue);
    expect(snapshot.player(184798).yellowCard, isFalse);
  });

  test('persists global, team, and player preferences independently', () async {
    final repository = LocalNotificationPreferencesRepository();

    await repository.saveGlobal(
      const GlobalNotificationPreferences(postComments: false),
    );
    await repository.saveTeam(
      83,
      const TeamNotificationPreferences(matchReminder: true),
    );
    await repository.savePlayer(
      184798,
      const PlayerNotificationPreferences(injury: true),
    );

    final snapshot = await repository.load();
    expect(snapshot.global.postComments, isFalse);
    expect(snapshot.team(83).matchReminder, isTrue);
    expect(snapshot.player(184798).injury, isTrue);
  });

  test('apply-to-all writes only the supplied followed entities', () async {
    final repository = LocalNotificationPreferencesRepository();
    const disabledTeams = TeamNotificationPreferences(
      news: false,
      kickoff: false,
      halfTime: false,
      fullTime: false,
      goal: false,
    );

    await repository.applyTeamToAll([83, 9], disabledTeams);

    final snapshot = await repository.load();
    expect(snapshot.team(83).news, isFalse);
    expect(snapshot.team(9).goal, isFalse);
    expect(snapshot.team(14).news, isTrue);
  });
}
