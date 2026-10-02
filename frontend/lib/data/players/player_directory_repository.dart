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

abstract interface class CachedPlayerWatchRepository
    implements PlayerDirectoryRepository {
  ValueListenable<List<PlayerWatch>?> get cachedWatch;
  Future<List<PlayerWatch>?> restoreCachedWatch();
  Future<List<PlayerWatch>> refreshWatch();
}

final PlayerDirectoryRepository playerDirectoryRepository =
    ApiPlayerDirectoryRepository(api: apiClient, cacheStore: localCacheStore);

class ApiPlayerDirectoryRepository implements CachedPlayerWatchRepository {
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
  final ValueNotifier<List<PlayerWatch>?> _cachedWatch = ValueNotifier(null);
  DateTime? _watchSavedAt;
  Future<List<PlayerWatch>>? _watchLoad;
  Future<List<PlayerWatch>>? _watchFetch;

  @override
  ValueListenable<List<PlayerWatch>?> get cachedWatch => _cachedWatch;

  @override
  ValueListenable<Map<PlayerDirectoryRankingQuery, PlayerRankingPage>>
      get cachedRankings => _cachedRankings;

  @override
  PlayerRankingPage? cachedRanking(
          {int? league, String? position, int offset = 0}) =>
      _cachedRankings
          .value[(league: league, position: position, offset: offset)];

  /// Promotes a local page to memory without starting an API request.
  Future<PlayerRankingPage?> restoreCachedRanking(
      {int? league, String? position, int offset = 0}) async {
    _validateQuery(league, position, offset);
    return cachedRanking(league: league, position: position, offset: offset) ??
        await _restore((league: league, position: position, offset: offset));
  }

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
    final alreadyCached = cachedRanking(
      league: query.league,
      position: query.position,
      offset: query.offset,
    );
    if (alreadyCached != null) return alreadyCached;
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
  Future<List<PlayerWatch>> watch() {
    final cached = _cachedWatch.value;
    if (cached != null) {
      _refreshWatchIfStale();
      return Future.value(cached);
    }
    final inFlight = _watchLoad;
    if (inFlight != null) return inFlight;
    late final Future<List<PlayerWatch>> load;
    load = _restoreOrFetchWatch().whenComplete(() {
      if (identical(_watchLoad, load)) _watchLoad = null;
    });
    _watchLoad = load;
    return load;
  }

  @override
  Future<List<PlayerWatch>?> restoreCachedWatch() async =>
      _cachedWatch.value ?? await _restoreWatch();

  @override
  Future<List<PlayerWatch>> refreshWatch() => _fetchWatch();

  Future<List<PlayerWatch>> _restoreOrFetchWatch() async {
    final restored = await _restoreWatch();
    if (restored != null) {
      _refreshWatchIfStale();
      return restored;
    }
    return _fetchWatch();
  }

  void _refreshWatchIfStale() {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _watchSavedAt,
    )) {
      unawaited(_fetchWatch().then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<List<PlayerWatch>?> _restoreWatch() async {
    final store = _cacheStore;
    if (store == null) return null;
    LocalCacheRecord? record;
    try {
      record = await store.read(LocalCacheKeys.onesToWatch);
    } on Object {
      return null;
    }
    if (record == null) return null;
    final cached = _cachedWatch.value;
    if (cached != null) return cached;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final players = _mapWatch(decoded);
      _publishWatch(players, record.savedAt);
      return players;
    } on Object {
      try {
        await store.delete(LocalCacheKeys.onesToWatch);
      } on Object {
        // A damaged row must not prevent an API recovery.
      }
      return null;
    }
  }

  Future<List<PlayerWatch>> _fetchWatch() {
    final inFlight = _watchFetch;
    if (inFlight != null) return inFlight;
    late final Future<List<PlayerWatch>> fetch;
    fetch = _fetchAndCacheWatch().whenComplete(() {
      if (identical(_watchFetch, fetch)) _watchFetch = null;
    });
    _watchFetch = fetch;
    return fetch;
  }

  Future<List<PlayerWatch>> _fetchAndCacheWatch() async {
    final json = await _get('players/ones-to-watch', {});
    final players = _mapWatch(json);
    _publishWatch(players, DateTime.now().toUtc());
    try {
      await _cacheStore?.write(LocalCacheKeys.onesToWatch, json);
    } on Object {
      // A storage failure must not hide a valid API response.
    }
    return players;
  }

  List<PlayerWatch> _mapWatch(Map<String, dynamic> json) {
    final items = json['items'] as List;
    if (items.length > 10) {
      throw const FormatException('Too many ones-to-watch players.');
    }
    final players = items.map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final player = (
        id: row['player_id'] as int,
        name: row['name'] as String,
        image: row['image'] as String?,
        jerseyNumber: row['jersey_number'] as int?,
        teamId: row['team_id'] as int?,
        teamName: row['team_name'] as String?,
        recent: (row['recent_average'] as num).toDouble(),
        previous: (row['previous_average'] as num).toDouble(),
        change: (row['change'] as num).toDouble(),
      );
      if (player.id < 1 ||
          player.name.trim().isEmpty ||
          !player.recent.isFinite ||
          !player.previous.isFinite ||
          !player.change.isFinite) {
        throw const FormatException('Invalid ones-to-watch player.');
      }
      return player;
    }).toList(growable: false);
    if (players.map((player) => player.id).toSet().length != players.length) {
      throw const FormatException('Duplicate ones-to-watch player.');
    }
    return List.unmodifiable(players);
  }

  void _publishWatch(List<PlayerWatch> players, DateTime savedAt) {
    _watchSavedAt = savedAt;
    _cachedWatch.value = players;
  }
}
