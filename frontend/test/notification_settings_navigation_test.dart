import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Profile_settings/Notification.dart';
import 'package:onetouch/data/notifications/notification_preferences.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository.dart';

import 'support/app_catalog.dart';

class _RecordingNotificationRepository
    implements NotificationPreferencesRepository {
  int? savedTeamId;
  int? savedPlayerId;
  Object? savedPreferences;

  @override
  Future<NotificationPreferenceSnapshot> load() async =>
      NotificationPreferenceSnapshot(
        teams: {83: const TeamNotificationPreferences().setAll(false)},
        players: {1: const PlayerNotificationPreferences().setAll(false)},
      );

  @override
  Future<void> saveTeam(
    int teamId,
    TeamNotificationPreferences preferences,
  ) async {
    savedTeamId = teamId;
    savedPreferences = preferences;
  }

  @override
  Future<void> savePlayer(
    int playerId,
    PlayerNotificationPreferences preferences,
  ) async {
    savedPlayerId = playerId;
    savedPreferences = preferences;
  }

  @override
  Future<void> applyPlayerToAll(
    Iterable<int> playerIds,
    PlayerNotificationPreferences preferences,
  ) async {}

  @override
  Future<void> applyTeamToAll(
    Iterable<int> teamIds,
    TeamNotificationPreferences preferences,
  ) async {}

  @override
  Future<void> applyNewBetsToAll(
    Iterable<int> teamIds,
    bool enabled,
  ) async {}

  @override
  Future<void> saveGlobal(GlobalNotificationPreferences preferences) async {}
}

void main() {
  setUpAppCatalog();

  for (final testCase in <({
    String name,
    String path,
    Widget Function(NotificationPreferencesRepository repository) page,
    int? Function(_RecordingNotificationRepository repository) savedId,
  })>[
    (
      name: 'team',
      path: '/team-notifications',
      page: (repository) => TeamNotificationDetailPage(
            teamName: 'FC Barcelona',
            teamId: 83,
            repository: repository,
          ),
      savedId: (repository) => repository.savedTeamId,
    ),
    (
      name: 'player',
      path: '/player-notifications',
      page: (repository) => PlayerNotificationDetailPage(
            playerName: 'Test Player',
            playerId: 1,
            repository: repository,
          ),
      savedId: (repository) => repository.savedPlayerId,
    ),
  ]) {
    testWidgets(
        '${testCase.name} update saves and returns to the previous page',
        (tester) async {
      final repository = _RecordingNotificationRepository();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => context.push(testCase.path),
                child: const Text('OPEN'),
              ),
            ),
          ),
          GoRoute(
            path: testCase.path,
            builder: (context, state) => testCase.page(repository),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UPDATE NOTIFICATIONS'));
      await tester.pumpAndSettle();

      expect(testCase.savedId(repository), isNotNull);
      switch (repository.savedPreferences) {
        case TeamNotificationPreferences preferences:
          expect(preferences.matchReminder, isFalse);
          expect(preferences.goal, isFalse);
          expect(preferences.substitution, isFalse);
        case PlayerNotificationPreferences preferences:
          expect(preferences.startingXi, isFalse);
          expect(preferences.goal, isFalse);
          expect(preferences.injury, isFalse);
        default:
          fail('Expected typed notification preferences to be saved.');
      }
      expect(find.text('OPEN'), findsOneWidget);
      expect(find.text('UPDATE NOTIFICATIONS'), findsNothing);
    });
  }
}
