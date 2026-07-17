import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const fallback = UserTeamPreferences(
    favoriteTeamId: 83,
    followedTeamIds: [83, 503],
  );

  test('loads and normalizes stored team preferences', () async {
    final repository = _FakeUserPreferencesRepository(
      stored: const UserTeamPreferences(
        favoriteTeamId: 8,
        followedTeamIds: [19, 8, 19, -1],
      ),
    );
    final preferences = CurrentUserPreferences(
      repository: repository,
      fallback: fallback,
    );

    await preferences.initialize();

    expect(preferences.favoriteTeamId.value, 8);
    expect(preferences.followedTeamIds.value, [8, 19]);
  });

  test('uses onboarding rank order and persists it', () async {
    final repository = _FakeUserPreferencesRepository();
    final preferences = CurrentUserPreferences(
      repository: repository,
      fallback: fallback,
    );

    await preferences.updateTeamSelection([19, 8]);

    expect(preferences.favoriteTeamId.value, 19);
    expect(preferences.followedTeamIds.value, [19, 8]);
    expect(repository.saved?.favoriteTeamId, 19);
    expect(repository.saved?.followedTeamIds, [19, 8]);
  });

  test('switching favorite keeps it inside followed teams', () async {
    final repository = _FakeUserPreferencesRepository();
    final preferences = CurrentUserPreferences(
      repository: repository,
      fallback: fallback,
    );

    await preferences.setFavoriteTeam(8);

    expect(preferences.favoriteTeamId.value, 8);
    expect(preferences.followedTeamIds.value, [8, 83, 503]);
    expect(repository.saved?.followedTeamIds, [8, 83, 503]);
  });

  test('local repository persists preferences between instances', () async {
    SharedPreferences.setMockInitialValues({});
    final writer = LocalUserPreferencesRepository();

    await writer.save(
      const UserTeamPreferences(
        favoriteTeamId: 19,
        followedTeamIds: [19, 8],
      ),
    );
    final stored = await LocalUserPreferencesRepository().load();

    expect(stored?.favoriteTeamId, 19);
    expect(stored?.followedTeamIds, [19, 8]);
  });
}

class _FakeUserPreferencesRepository implements UserPreferencesRepository {
  _FakeUserPreferencesRepository({this.stored});

  UserTeamPreferences? stored;
  UserTeamPreferences? saved;

  @override
  Future<UserTeamPreferences?> load() async => stored;

  @override
  Future<void> save(UserTeamPreferences preferences) async {
    saved = preferences;
  }
}
