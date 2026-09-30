import 'dart:convert';

import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/notifications/notification_preferences.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository.dart';

/// API implementation of the authenticated user's notification preferences.
class ApiNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  ApiNotificationPreferencesRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<NotificationPreferenceSnapshot> load() async {
    final response = await _api.get(
      _api.baseUri.resolve('users/me/notification-preferences'),
    );
    return _decodeSnapshot(
      _api.decodeJson<Map<String, dynamic>>(response),
    );
  }

  @override
  Future<void> saveGlobal(
    GlobalNotificationPreferences preferences,
  ) async {
    await _patch(
      scope: 'community',
      preferences: {
        'post_reactions': preferences.postReactions,
        'post_comments': preferences.postComments,
      },
    );
  }

  @override
  Future<void> saveTeam(
    int teamId,
    TeamNotificationPreferences preferences,
  ) async {
    await _patch(
      scope: 'team',
      preferences: _teamEventPreferences(preferences),
      subjectIds: [_validId(teamId, 'teamId')],
    );
  }

  @override
  Future<void> applyTeamToAll(
    Iterable<int> teamIds,
    TeamNotificationPreferences preferences,
  ) async {
    final ids = _validIds(teamIds, 'teamIds');
    if (ids.isEmpty) return;
    await _patch(
      scope: 'team',
      preferences: _teamEventPreferences(preferences),
      subjectIds: ids,
    );
  }

  @override
  Future<void> applyNewBetsToAll(
    Iterable<int> teamIds,
    bool enabled,
  ) async {
    final ids = _validIds(teamIds, 'teamIds');
    if (ids.isEmpty) return;
    await _patch(
      scope: 'team',
      preferences: {'new_bets': enabled},
      subjectIds: ids,
    );
  }

  @override
  Future<void> savePlayer(
    int playerId,
    PlayerNotificationPreferences preferences,
  ) async {
    await _patch(
      scope: 'player',
      preferences: _playerPreferences(preferences),
      subjectIds: [_validId(playerId, 'playerId')],
    );
  }

  @override
  Future<void> applyPlayerToAll(
    Iterable<int> playerIds,
    PlayerNotificationPreferences preferences,
  ) async {
    final ids = _validIds(playerIds, 'playerIds');
    if (ids.isEmpty) return;
    await _patch(
      scope: 'player',
      preferences: _playerPreferences(preferences),
      subjectIds: ids,
    );
  }

  Future<NotificationPreferenceSnapshot> _patch({
    required String scope,
    required Map<String, bool> preferences,
    List<int>? subjectIds,
  }) async {
    final response = await _api.patch(
      _api.baseUri.resolve('users/me/notification-preferences/$scope'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'preferences': preferences,
        if (subjectIds != null) 'subject_ids': subjectIds,
      }),
    );
    return _decodeSnapshot(
      _api.decodeJson<Map<String, dynamic>>(response),
    );
  }

  Map<String, bool> _teamEventPreferences(
    TeamNotificationPreferences value,
  ) =>
      {
        // New bets is controlled by the global-looking bulk switch in the UI.
        'match_reminder': value.matchReminder,
        'kickoff': value.kickoff,
        'half_time': value.halfTime,
        'full_time': value.fullTime,
        'goal': value.goal,
        'substitution': value.substitution,
      };

  Map<String, bool> _playerPreferences(
    PlayerNotificationPreferences value,
  ) =>
      {
        'starting_xi': value.startingXi,
        'substitute': value.substitute,
        'goal': value.goal,
        'assist': value.assist,
        'yellow_card': value.yellowCard,
        'red_card': value.redCard,
        'injury': value.injury,
      };

  NotificationPreferenceSnapshot _decodeSnapshot(Map<String, dynamic> json) {
    final community = _requiredMap(json, 'community');
    final teams = _requiredMap(json, 'teams');
    final players = _requiredMap(json, 'players');
    return NotificationPreferenceSnapshot(
      global: GlobalNotificationPreferences(
        postReactions: _requiredBool(community, 'post_reactions'),
        postComments: _requiredBool(community, 'post_comments'),
      ),
      teams: Map.unmodifiable({
        for (final entry in teams.entries)
          _subjectId(entry.key, 'teams'): _decodeTeam(
            _objectMap(entry.value, 'teams.${entry.key}'),
          ),
      }),
      players: Map.unmodifiable({
        for (final entry in players.entries)
          _subjectId(entry.key, 'players'): _decodePlayer(
            _objectMap(entry.value, 'players.${entry.key}'),
          ),
      }),
    );
  }

  TeamNotificationPreferences _decodeTeam(Map<String, dynamic> json) =>
      TeamNotificationPreferences(
        newBets: _requiredBool(json, 'new_bets'),
        matchReminder: _requiredBool(json, 'match_reminder'),
        kickoff: _requiredBool(json, 'kickoff'),
        halfTime: _requiredBool(json, 'half_time'),
        fullTime: _requiredBool(json, 'full_time'),
        goal: _requiredBool(json, 'goal'),
        substitution: _requiredBool(json, 'substitution'),
      );

  PlayerNotificationPreferences _decodePlayer(Map<String, dynamic> json) =>
      PlayerNotificationPreferences(
        startingXi: _requiredBool(json, 'starting_xi'),
        substitute: _requiredBool(json, 'substitute'),
        goal: _requiredBool(json, 'goal'),
        assist: _requiredBool(json, 'assist'),
        yellowCard: _requiredBool(json, 'yellow_card'),
        redCard: _requiredBool(json, 'red_card'),
        injury: _requiredBool(json, 'injury'),
      );

  Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) =>
      _objectMap(json[key], key);

  Map<String, dynamic> _objectMap(Object? value, String field) {
    if (value is! Map) {
      throw FormatException('Expected "$field" to be an object.');
    }
    return value.cast<String, dynamic>();
  }

  bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw FormatException('Expected "$key" to be a boolean.');
    }
    return value;
  }

  int _subjectId(String value, String field) {
    final id = int.tryParse(value);
    if (id == null || id < 1) {
      throw FormatException('Expected a positive subject ID in "$field".');
    }
    return id;
  }

  int _validId(int value, String name) {
    if (value < 1) throw RangeError.value(value, name, 'Must be positive');
    return value;
  }

  List<int> _validIds(Iterable<int> values, String name) {
    final ids = values.map((value) => _validId(value, name)).toList();
    if (ids.length > 1000) {
      throw RangeError.range(ids.length, 0, 1000, name);
    }
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(ids, name, 'Must not contain duplicates');
    }
    return List.unmodifiable(ids);
  }
}
