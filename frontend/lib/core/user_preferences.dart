import 'package:flutter/foundation.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart';
import 'package:onetouch/data/teams/following_teams_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class UserTeamPreferences {
  const UserTeamPreferences({
    required this.favoriteTeamId,
    required this.followedTeamIds,
  });

  final int favoriteTeamId;
  final List<int> followedTeamIds;
}

/// 온보딩과 화면이 같은 저장 규칙으로 응원팀을 관리해요.
abstract interface class UserPreferencesRepository {
  Future<UserTeamPreferences?> load();

  Future<void> save(UserTeamPreferences preferences);
}

class LocalUserPreferencesRepository implements UserPreferencesRepository {
  static const _favoriteTeamKey = 'current_user.favorite_team_id';
  static const _followedTeamsKey = 'current_user.followed_team_ids';

  @override
  Future<UserTeamPreferences?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final favoriteTeamId = preferences.getInt(_favoriteTeamKey);
    final followedTeamIds = preferences
        .getStringList(_followedTeamsKey)
        ?.map(int.tryParse)
        .whereType<int>()
        .toList();

    if (favoriteTeamId == null || followedTeamIds == null) return null;
    return UserTeamPreferences(
      favoriteTeamId: favoriteTeamId,
      followedTeamIds: followedTeamIds,
    );
  }

  @override
  Future<void> save(UserTeamPreferences preferences) async {
    final storage = await SharedPreferences.getInstance();
    await storage.setInt(_favoriteTeamKey, preferences.favoriteTeamId);
    await storage.setStringList(
      _followedTeamsKey,
      preferences.followedTeamIds.map((id) => '$id').toList(),
    );
  }
}

class CurrentUserPreferences {
  CurrentUserPreferences({
    required UserPreferencesRepository repository,
    required TeamRepository teamRepository,
    UserTeamPreferences? fallback,
  })  : _repository = repository,
        _teamRepository = teamRepository,
        _fallback = fallback {
    if (fallback != null) _apply(fallback);
  }

  final UserPreferencesRepository _repository;
  final TeamRepository _teamRepository;
  final UserTeamPreferences? _fallback;

  late final ValueNotifier<int> favoriteTeamId;
  final followedTeamIds = ValueNotifier<List<int>>(const []);
  bool _hasFavorite = false;

  Future<void> initialize() async {
    await _teamRepository.initialize();
    final stored = await _repository.load() ?? _fallback;
    if (stored != null) _apply(stored);
  }

  // 서버에서 이미 저장한 결과를 반영할 때는 PUT을 반복하지 않아요.
  void applyServerSelection(UserTeamPreferences preferences) =>
      _apply(preferences);

  Future<void> updateTeamSelection(Iterable<int> rankedTeamIds) async {
    final selectedIds = _validDistinctTeamIds(rankedTeamIds);
    if (selectedIds.isEmpty) return;

    await _save(
      UserTeamPreferences(
        favoriteTeamId: selectedIds.first,
        followedTeamIds: selectedIds,
      ),
    );
  }

  Future<void> setFavoriteTeam(int teamId) async {
    if (!_isValidTeamId(teamId)) return;

    final reorderedTeamIds = [
      teamId,
      ...followedTeamIds.value.where((id) => id != teamId),
    ];
    await _save(
      UserTeamPreferences(
        favoriteTeamId: teamId,
        followedTeamIds: reorderedTeamIds,
      ),
    );
  }

  /// Replaces the user's followed-team list while preserving the current
  /// favorite whenever it is still selected.
  Future<bool> updateFollowedTeams(Iterable<int> teamIds) async {
    final selectedIds = _validDistinctTeamIds(teamIds);
    if (selectedIds.isEmpty) return false;

    final favoriteId = selectedIds.contains(favoriteTeamId.value)
        ? favoriteTeamId.value
        : selectedIds.first;
    await _save(
      UserTeamPreferences(
        favoriteTeamId: favoriteId,
        followedTeamIds: selectedIds,
      ),
    );
    return true;
  }

  /// Adds or removes a followed team. At least one team must remain because
  /// the home, team, and community tabs all require a current favorite.
  Future<bool> toggleFollowedTeam(int teamId) async {
    if (!_isValidTeamId(teamId)) return false;

    final selectedIds = followedTeamIds.value.toList();
    if (!selectedIds.contains(teamId)) {
      selectedIds.add(teamId);
    } else {
      if (selectedIds.length == 1) return false;
      selectedIds.remove(teamId);
    }

    return updateFollowedTeams(selectedIds);
  }

  void _apply(UserTeamPreferences preferences) {
    var selectedIds = _validDistinctTeamIds(preferences.followedTeamIds);
    var favoriteId = preferences.favoriteTeamId;

    if (!_isValidTeamId(favoriteId)) {
      throw StateError('Favorite team is missing from the catalog.');
    }
    selectedIds = [
      favoriteId,
      ...selectedIds.where((id) => id != favoriteId),
    ];

    if (_hasFavorite) {
      favoriteTeamId.value = favoriteId;
    } else {
      favoriteTeamId = ValueNotifier(favoriteId);
      _hasFavorite = true;
    }
    followedTeamIds.value = List.unmodifiable(selectedIds);
  }

  Future<void> _save(UserTeamPreferences preferences) async {
    await _repository.save(preferences);
    _apply(preferences);
  }

  List<int> _validDistinctTeamIds(Iterable<int> teamIds) {
    return teamIds.where(_isValidTeamId).toSet().toList();
  }

  bool _isValidTeamId(int teamId) => _teamRepository.contains(teamId);
}

class ApiUserPreferencesRepository implements UserPreferencesRepository {
  @override
  Future<UserTeamPreferences?> load() async {
    final account = await currentUserRepository.loadAccount();
    if (account.favoriteTeamId == null) return null;
    final teams = await followingTeamsRepository.load();
    return UserTeamPreferences(
      favoriteTeamId: account.favoriteTeamId!,
      followedTeamIds: teams.map((team) => team.teamId).toList(),
    );
  }

  @override
  Future<void> save(UserTeamPreferences preferences) async {
    await followingTeamsRepository.replaceFollowing(
      teamIds: preferences.followedTeamIds,
      favoriteTeamId: preferences.favoriteTeamId,
    );
  }
}

final currentUserPreferences = CurrentUserPreferences(
  repository: ApiUserPreferencesRepository(),
  teamRepository: teamRepository,
);
