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
  static const communityPosts = 'community-posts';

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

  static String standings(int competitionId, int? seasonId) =>
      'standings:$competitionId:${seasonId ?? 'current'}';

  static String xgStandings(int competitionId, int? seasonId) =>
      'xg-standings:$competitionId:${seasonId ?? 'current'}';

  static String teamMatches(
    int teamId,
    String status,
    String? start,
    String? end,
    int limit,
    int offset,
  ) =>
      'team-matches:$teamId:$status:${start ?? 'all'}:${end ?? 'all'}:'
      '$limit:$offset';

  static String fixtureDetail(int fixtureId) => 'fixture-detail:$fixtureId';

  static String playerRankings(int seasonId, int limit, int offset) =>
      'player-rankings:$seasonId:$limit:$offset';

  static String currentPlayerRanking(
    int? league,
    String? position,
    int limit,
    int offset,
  ) =>
      'current-player-ranking:${league ?? 'all'}:${position ?? 'all'}:'
      '$limit:$offset';

  // 5+5경기로 선정한 캐시가 새 3+3경기 결과에 섞이지 않게 해요.
  static const onesToWatch = 'players-ones-to-watch:v2';

  static String communityFeed(
    int teamId,
    String language,
    String? category,
    String sort,
    String period,
    String? timezone,
    int limit,
    int offset,
  ) =>
      'community-feed:$teamId:$language:${category ?? 'all'}:$sort:$period:'
      '${Uri.encodeComponent(timezone ?? 'all')}:$limit:$offset';

  // 언어 필드가 없던 상세 캐시를 새 응답으로 읽지 않아요.
  static String communityPost(int postId) => 'community-post:v2:$postId';

  // 국가를 고정해 저장한 구버전 캐시와 구분해요. 하이라이트는 저장하지 않아요.
  static String home(int teamId, DateTime month) =>
      'home:v2:$teamId:${month.year}-${month.month.toString().padLeft(2, '0')}';

  // 지표가 빠진 구버전 캐시를 재사용하면 상세 진입 때 별도 로딩이 반복돼요.
  static String playerDetail(int playerId, int? seasonId) =>
      'player-detail:v2:$playerId:${seasonId ?? 'current'}';

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
