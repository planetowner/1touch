import 'dart:convert';

import 'package:onetouch/data/notifications/notification_preferences.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  LocalNotificationPreferencesRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _storageKey = 'current_user.notification_preferences.v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _storage async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<NotificationPreferenceSnapshot> load() async {
    final encoded = (await _storage).getString(_storageKey);
    if (encoded == null) return const NotificationPreferenceSnapshot();
    try {
      return _decode(jsonDecode(encoded) as Map<String, dynamic>);
    } on Object {
      return const NotificationPreferenceSnapshot();
    }
  }

  @override
  Future<void> saveGlobal(GlobalNotificationPreferences preferences) async {
    final current = await load();
    await _write(NotificationPreferenceSnapshot(
      global: preferences,
      teams: current.teams,
      players: current.players,
    ));
  }

  @override
  Future<void> saveTeam(
    int teamId,
    TeamNotificationPreferences preferences,
  ) async {
    final current = await load();
    await _write(NotificationPreferenceSnapshot(
      global: current.global,
      teams: {...current.teams, teamId: preferences},
      players: current.players,
    ));
  }

  @override
  Future<void> applyTeamToAll(
    Iterable<int> teamIds,
    TeamNotificationPreferences preferences,
  ) async {
    final current = await load();
    final teams = Map<int, TeamNotificationPreferences>.of(current.teams);
    for (final teamId in teamIds) {
      teams[teamId] = preferences;
    }
    await _write(NotificationPreferenceSnapshot(
      global: current.global,
      teams: teams,
      players: current.players,
    ));
  }

  @override
  Future<void> savePlayer(
    int playerId,
    PlayerNotificationPreferences preferences,
  ) async {
    final current = await load();
    await _write(NotificationPreferenceSnapshot(
      global: current.global,
      teams: current.teams,
      players: {...current.players, playerId: preferences},
    ));
  }

  @override
  Future<void> applyPlayerToAll(
    Iterable<int> playerIds,
    PlayerNotificationPreferences preferences,
  ) async {
    final current = await load();
    final players = Map<int, PlayerNotificationPreferences>.of(current.players);
    for (final playerId in playerIds) {
      players[playerId] = preferences;
    }
    await _write(NotificationPreferenceSnapshot(
      global: current.global,
      teams: current.teams,
      players: players,
    ));
  }

  Future<void> _write(NotificationPreferenceSnapshot snapshot) async {
    await (await _storage)
        .setString(_storageKey, jsonEncode(_encode(snapshot)));
  }

  Map<String, dynamic> _encode(NotificationPreferenceSnapshot snapshot) => {
        'global': {
          'post_reactions': snapshot.global.postReactions,
          'post_comments': snapshot.global.postComments,
          'new_bets': snapshot.global.newBets,
          'post_match_results': snapshot.global.postMatchResults,
        },
        'teams': {
          for (final entry in snapshot.teams.entries)
            '${entry.key}': {
              'news': entry.value.news,
              'match_reminder': entry.value.matchReminder,
              'kickoff': entry.value.kickoff,
              'half_time': entry.value.halfTime,
              'full_time': entry.value.fullTime,
              'goal': entry.value.goal,
              'substitution': entry.value.substitution,
            },
        },
        'players': {
          for (final entry in snapshot.players.entries)
            '${entry.key}': {
              'starting_xi': entry.value.startingXi,
              'substitute': entry.value.substitute,
              'goal': entry.value.goal,
              'assist': entry.value.assist,
              'yellow_card': entry.value.yellowCard,
              'red_card': entry.value.redCard,
              'injury': entry.value.injury,
            },
        },
      };

  NotificationPreferenceSnapshot _decode(Map<String, dynamic> json) {
    final global = _map(json['global']);
    final teams = _map(json['teams']);
    final players = _map(json['players']);
    return NotificationPreferenceSnapshot(
      global: GlobalNotificationPreferences(
        postReactions: _bool(global, 'post_reactions', true),
        postComments: _bool(global, 'post_comments', true),
        newBets: _bool(global, 'new_bets', true),
        postMatchResults: _bool(global, 'post_match_results', true),
      ),
      teams: {
        for (final entry in teams.entries)
          if (int.tryParse(entry.key) case final int teamId)
            teamId: _decodeTeam(_map(entry.value)),
      },
      players: {
        for (final entry in players.entries)
          if (int.tryParse(entry.key) case final int playerId)
            playerId: _decodePlayer(_map(entry.value)),
      },
    );
  }

  TeamNotificationPreferences _decodeTeam(Map<String, dynamic> json) =>
      TeamNotificationPreferences(
        news: _bool(json, 'news', true),
        matchReminder: _bool(json, 'match_reminder', false),
        kickoff: _bool(json, 'kickoff', true),
        halfTime: _bool(json, 'half_time', true),
        fullTime: _bool(json, 'full_time', true),
        goal: _bool(json, 'goal', true),
        substitution: _bool(json, 'substitution', false),
      );

  PlayerNotificationPreferences _decodePlayer(Map<String, dynamic> json) =>
      PlayerNotificationPreferences(
        startingXi: _bool(json, 'starting_xi', true),
        substitute: _bool(json, 'substitute', true),
        goal: _bool(json, 'goal', true),
        assist: _bool(json, 'assist', true),
        yellowCard: _bool(json, 'yellow_card', false),
        redCard: _bool(json, 'red_card', false),
        injury: _bool(json, 'injury', false),
      );

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : const {};

  bool _bool(Map<String, dynamic> json, String key, bool fallback) =>
      json[key] is bool ? json[key] as bool : fallback;
}
