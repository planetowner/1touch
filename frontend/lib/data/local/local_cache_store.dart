import 'dart:convert';

class LocalCacheRecord {
  const LocalCacheRecord({
    required this.payload,
    required this.savedAt,
    required this.schemaVersion,
  });

  final Object payload;
  final DateTime savedAt;
  final int schemaVersion;
}

abstract interface class LocalCacheStore {
  Future<LocalCacheRecord?> read(
    String key, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  });

  Future<void> write(
    String key,
    Object payload, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  });

  Future<void> delete(
    String key, {
    String scope = LocalCacheScopes.global,
  });

  Future<void> clearScope(String scope);
}

abstract final class LocalCacheScopes {
  static const global = 'global';

  /// A device has one active authenticated account at a time. This entire
  /// scope is cleared before a new sign-in and during local logout.
  static const authenticatedUser = 'authenticated-user';
}

abstract final class LocalCacheKeys {
  static const catalog = 'catalog';
  static const currentUser = 'current-user';
  static const followingTeams = 'following-teams';
  static const followingPlayers = 'following-players';

  static String teamOverview(int teamId) => 'team-overview:$teamId';

  static String home(int teamId, DateTime month, String viewerCountry) =>
      'home:$teamId:${month.year}-${month.month.toString().padLeft(2, '0')}:'
      '$viewerCountry';

  static String playerDetail(int playerId, int? seasonId) =>
      'player-detail:$playerId:${seasonId ?? 'current'}';

  static String teamContracts(int teamId, int? seasonId) =>
      'team-contracts:$teamId:${seasonId ?? 'current'}';

  static String teamAttributeOptions(int teamId) =>
      'team-attribute-options:$teamId';

  static String teamAttributes(int teamId, int? seasonId) =>
      'team-attributes:$teamId:${seasonId ?? 'current'}';

  static String currentFormOptions(
    int teamId,
    String search,
    int limit, {
    String? seasonName,
  }) =>
      'current-form-options:$teamId:${Uri.encodeComponent(search)}:$limit'
      '${seasonName == null ? '' : ':season:${Uri.encodeComponent(seasonName)}'}';

  static String currentFormComparison(
    int teamId,
    int? seasonId,
    int compareTeamId,
    int compareSeasonId,
  ) =>
      'current-form-comparison:$teamId:${seasonId ?? 'current'}:'
      '$compareTeamId:$compareSeasonId';

  static String teamProbability(int teamId, int? seasonId) =>
      'team-probability:$teamId:${seasonId ?? 'current'}';

  static String bestEleven(
    int teamId,
    int? seasonId,
    String? formation,
  ) =>
      'best-eleven:$teamId:${seasonId ?? 'current'}:'
      '${Uri.encodeComponent(formation ?? 'default')}';

  static String teamInjuries(int teamId) => 'team-injuries:$teamId';
}

/// Deterministic in-memory implementation used by repository unit tests.
class MemoryLocalCacheStore implements LocalCacheStore {
  final Map<(String, String), LocalCacheRecord> _records = {};

  @override
  Future<LocalCacheRecord?> read(
    String key, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async {
    final record = _records[(scope, key)];
    if (record == null || record.schemaVersion != schemaVersion) return null;
    return LocalCacheRecord(
      payload: jsonDecode(jsonEncode(record.payload)) as Object,
      savedAt: record.savedAt,
      schemaVersion: record.schemaVersion,
    );
  }

  @override
  Future<void> write(
    String key,
    Object payload, {
    String scope = LocalCacheScopes.global,
    int schemaVersion = 1,
  }) async {
    _records[(scope, key)] = LocalCacheRecord(
      payload: jsonDecode(jsonEncode(payload)) as Object,
      savedAt: DateTime.now().toUtc(),
      schemaVersion: schemaVersion,
    );
  }

  @override
  Future<void> delete(
    String key, {
    String scope = LocalCacheScopes.global,
  }) async {
    _records.remove((scope, key));
  }

  @override
  Future<void> clearScope(String scope) async {
    _records.removeWhere((key, _) => key.$1 == scope);
  }
}
