import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

typedef PlayerDirectoryRankingQuery = ({
  int? league,
  String? position,
  int offset,
});

typedef PlayerLeague = ({int id, String name, int available});
typedef PlayerRank = ({
  int id,
  String name,
  String? image,
  String? position,
  int rank,
  double score,
  double rating,
  int appearances
});
typedef PlayerWatch = ({
  int id,
  String name,
  String? image,
  int? jerseyNumber,
  int? teamId,
  String? teamName,
  double recent,
  double previous,
  double change
});

class PlayerRankingPage {
  PlayerRankingPage(
      {required this.season,
      required List<PlayerLeague> leagues,
      required List<PlayerRank> items,
      required this.total})
      : leagues = List.unmodifiable(leagues),
        items = List.unmodifiable(items);
  final String? season;
  final List<PlayerLeague> leagues;
  final List<PlayerRank> items;
  final int total;
}

abstract interface class PlayerDirectoryRepository {
  ValueListenable<Map<PlayerDirectoryRankingQuery, PlayerRankingPage>>
      get cachedRankings;

  PlayerRankingPage? cachedRanking(
      {int? league, String? position, int offset = 0});

  Future<PlayerRankingPage> ranking(
      {int? league, String? position, int offset = 0});
  Future<PlayerRankingPage> refreshRanking(
      {int? league, String? position, int offset = 0});
  Future<List<PlayerWatch>> watch();
}

final PlayerDirectoryRepository playerDirectoryRepository =
    ApiPlayerDirectoryRepository(api: apiClient, cacheStore: localCacheStore);

class ApiPlayerDirectoryRepository implements PlayerDirectoryRepository {
  ApiPlayerDirectoryRepository(
      {required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;
  static const _rankingLimit = 100;
  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final ValueNotifier<Map<PlayerDirectoryRankingQuery, PlayerRankingPage>>
      _cachedRankings = ValueNotifier(const {});
  final Map<PlayerDirectoryRankingQuery, DateTime> _savedAt = {};
  final Map<PlayerDirectoryRankingQuery, Future<PlayerRankingPage>>
      _inFlightLoads = {};
  final Map<PlayerDirectoryRankingQuery, Future<PlayerRankingPage>>
      _inFlightFetches = {};

  @override
  ValueListenable<Map<PlayerDirectoryRankingQuery, PlayerRankingPage>>
      get cachedRankings => _cachedRankings;

  @override
  PlayerRankingPage? cachedRanking(
          {int? league, String? position, int offset = 0}) =>
      _cachedRankings
          .value[(league: league, position: position, offset: offset)];

  @override
  Future<PlayerRankingPage> ranking(
      {int? league, String? position, int offset = 0}) async {
    _validateQuery(league, position, offset);
    final query = (league: league, position: position, offset: offset);
    final cached = _cachedRankings.value[query];
    if (cached != null) {
      _refreshIfStale(query);
      return cached;
    }
    final inFlight = _inFlightLoads[query];
    if (inFlight != null) return await inFlight;

    late final Future<PlayerRankingPage> load;
    load = _restoreOrFetch(query).whenComplete(() {
      if (identical(_inFlightLoads[query], load)) _inFlightLoads.remove(query);
    });
    _inFlightLoads[query] = load;
    return await load;
  }

  @override
  Future<PlayerRankingPage> refreshRanking(
      {int? league, String? position, int offset = 0}) async {
    _validateQuery(league, position, offset);
    return _fetch((league: league, position: position, offset: offset));
  }

  void _validateQuery(int? league, String? position, int offset) {
    if (league != null && league < 1) {
      throw RangeError.value(league, 'league', 'Must be positive');
    }
    if (position != null &&
        !const {'GK', 'DF', 'MF', 'FW'}.contains(position)) {
      throw ArgumentError.value(position, 'position', 'Unsupported position');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Must not be negative');
    }
  }

  Future<PlayerRankingPage> _restoreOrFetch(
      PlayerDirectoryRankingQuery query) async {
    final restored = await _restore(query);
    if (restored != null) {
      _refreshIfStale(query);
      return restored;
    }
    return _fetch(query);
  }

  void _refreshIfStale(PlayerDirectoryRankingQuery query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      unawaited(_fetch(query).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<PlayerRankingPage?> _restore(PlayerDirectoryRankingQuery query) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = _key(query);
    LocalCacheRecord? record;
    try {
      record = await store.read(key);
    } on Object {
      return null;
    }
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final page = _mapRanking(decoded, query);
      _publish(query, page, record.savedAt);
      return page;
    } on Object {
      try {
        await store.delete(key);
      } on Object {
        // A damaged page must not block recovery from the API.
      }
      return null;
    }
  }

  Future<PlayerRankingPage> _fetch(PlayerDirectoryRankingQuery query) {
    final inFlight = _inFlightFetches[query];
    if (inFlight != null) return inFlight;
    late final Future<PlayerRankingPage> fetch;
    fetch = _fetchAndCache(query).whenComplete(() {
      if (identical(_inFlightFetches[query], fetch)) {
        _inFlightFetches.remove(query);
      }
    });
    _inFlightFetches[query] = fetch;
    return fetch;
  }

  Future<PlayerRankingPage> _fetchAndCache(
      PlayerDirectoryRankingQuery query) async {
    final json = await _get('players/ranking-current', {
      if (query.league != null) 'competition_id': '${query.league}',
      if (query.position != null) 'position': query.position!,
      'offset': '${query.offset}',
      'limit': '$_rankingLimit',
    });
    final page = _mapRanking(json, query);
    _publish(query, page, DateTime.now().toUtc());
    try {
      await _cacheStore?.write(_key(query), json);
    } on Object {
      // Storage failure must not hide a valid API response.
    }
    return page;
  }

  PlayerRankingPage _mapRanking(
    Map<String, dynamic> json,
    PlayerDirectoryRankingQuery query,
  ) {
    if (json['limit'] != _rankingLimit ||
        json['offset'] != query.offset ||
        json['competition_id'] != query.league ||
        json['position'] != query.position) {
      throw const FormatException('Unexpected current ranking page identity.');
    }
    final leagues = (json['leagues'] as List)
        .map((r) => (
              id: r['competition_id'] as int,
              name: r['name'] as String,
              available: r['available_players'] as int
            ))
        .toList();
    final items = (json['items'] as List)
        .map((r) => (
              id: r['player_id'] as int,
              name: r['name'] as String,
              image: r['image'] as String?,
              position: r['position'] as String?,
              rank: r['rank'] as int,
              score: (r['display_score'] as num).toDouble(),
              rating: (r['average_rating'] as num).toDouble(),
              appearances: r['rated_matches'] as int
            ))
        .toList();
    final total = json['total'] as int;
    if (total < 0 || items.length > _rankingLimit) {
      throw const FormatException('Invalid current ranking pagination.');
    }
    return PlayerRankingPage(
      season: json['season_name'] as String?,
      total: total,
      leagues: leagues,
      items: items,
    );
  }

  void _publish(PlayerDirectoryRankingQuery query, PlayerRankingPage page,
      DateTime savedAt) {
    _savedAt[query] = savedAt;
    _cachedRankings.value =
        Map.unmodifiable({..._cachedRankings.value, query: page});
  }

  String _key(PlayerDirectoryRankingQuery query) =>
      LocalCacheKeys.currentPlayerRanking(
        query.league,
        query.position,
        _rankingLimit,
        query.offset,
      );

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> params) async {
    final uri = _api.baseUri
        .resolve(path)
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await _api.get(uri);
    return _api.decodeJson<Map<String, dynamic>>(response);
  }

  @override
  Future<List<PlayerWatch>> watch() async {
    final json = await _get('players/ones-to-watch', {});
    return (json['items'] as List)
        .map((r) => (
              id: r['player_id'] as int,
              name: r['name'] as String,
              image: r['image'] as String?,
              jerseyNumber: r['jersey_number'] as int?,
              teamId: r['team_id'] as int?,
              teamName: r['team_name'] as String?,
              recent: (r['recent_average'] as num).toDouble(),
              previous: (r['previous_average'] as num).toDouble(),
              change: (r['change'] as num).toDouble()
            ))
        .toList();
  }
}
