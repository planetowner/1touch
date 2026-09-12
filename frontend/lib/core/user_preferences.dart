import 'package:flutter/foundation.dart';
import 'package:onetouch/data/community/mock/community_catalog.dart';
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

/// Storage boundary for the current user's preferences.
///
/// The local implementation can later be replaced with an API-backed
/// repository without changing onboarding or the screens that consume it.
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
    required UserTeamPreferences fallback,
  })  : _repository = repository,
        _teamRepository = teamRepository,
        _fallback = fallback,
        favoriteTeamId = ValueNotifier(fallback.favoriteTeamId),
        followedTeamIds = ValueNotifier(
          List.unmodifiable(fallback.followedTeamIds),
        );

  final UserPreferencesRepository _repository;
  final TeamRepository _teamRepository;
  final UserTeamPreferences _fallback;

  final ValueNotifier<int> favoriteTeamId;
  final ValueNotifier<List<int>> followedTeamIds;

  Future<void> initialize() async {
    try {
      await _teamRepository.initialize();
      final stored = await _repository.load();
      _apply(stored ?? _fallback);
    } on Object catch (error) {
      debugPrint('Unable to load local user preferences: $error');
      _apply(_fallback);
    }
  }

  Future<void> updateTeamSelection(Iterable<int> rankedTeamIds) async {
    final selectedIds = _validDistinctTeamIds(rankedTeamIds);
    if (selectedIds.isEmpty) return;

    _apply(
      UserTeamPreferences(
        favoriteTeamId: selectedIds.first,
        followedTeamIds: selectedIds,
      ),
    );
    await _persist();
  }

  Future<void> setFavoriteTeam(int teamId) async {
    if (!_isValidTeamId(teamId)) return;

    final reorderedTeamIds = [
      teamId,
      ...followedTeamIds.value.where((id) => id != teamId),
    ];
    _apply(
      UserTeamPreferences(
        favoriteTeamId: teamId,
        followedTeamIds: reorderedTeamIds,
      ),
    );
    await _persist();
  }

  /// Replaces the user's followed-team list while preserving the current
  /// favorite whenever it is still selected.
  Future<bool> updateFollowedTeams(Iterable<int> teamIds) async {
    final selectedIds = _validDistinctTeamIds(teamIds);
    if (selectedIds.isEmpty) return false;

    final favoriteId = selectedIds.contains(favoriteTeamId.value)
        ? favoriteTeamId.value
        : selectedIds.first;
    _apply(
      UserTeamPreferences(
        favoriteTeamId: favoriteId,
        followedTeamIds: selectedIds,
      ),
    );
    await _persist();
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

    if (!_isValidTeamId(favoriteId)) favoriteId = _fallback.favoriteTeamId;
    if (selectedIds.isEmpty) {
      selectedIds = _validDistinctTeamIds(_fallback.followedTeamIds);
    }
    selectedIds = [
      favoriteId,
      ...selectedIds.where((id) => id != favoriteId),
    ];

    favoriteTeamId.value = favoriteId;
    followedTeamIds.value = List.unmodifiable(selectedIds);
  }

  Future<void> _persist() async {
    try {
      await _repository.save(
        UserTeamPreferences(
          favoriteTeamId: favoriteTeamId.value,
          followedTeamIds: followedTeamIds.value,
        ),
      );
    } on Object catch (error) {
      debugPrint('Unable to save local user preferences: $error');
    }
  }

  List<int> _validDistinctTeamIds(Iterable<int> teamIds) {
    return teamIds.where(_isValidTeamId).toSet().toList();
  }

  bool _isValidTeamId(int teamId) => _teamRepository.contains(teamId);
}

final currentUserPreferences = CurrentUserPreferences(
  repository: LocalUserPreferencesRepository(),
  teamRepository: teamRepository,
  fallback: UserTeamPreferences(
    favoriteTeamId: mockUserProfileById(1001).favoriteTeamId ??
        followingTeamIds(1001).first,
    followedTeamIds: followingTeamIds(1001),
  ),
);
