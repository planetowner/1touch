import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/players/api/api_player_rankings_mapper.dart';
import 'package:onetouch/data/players/api/api_player_rankings_response.dart';
import 'package:onetouch/data/players/player_rankings_repository.dart';
import 'package:onetouch/models/player_rankings.dart';

/// HTTP implementation of `GET /v1/players/rankings`.
class ApiPlayerRankingsRepository implements PlayerRankingsRepository {
  ApiPlayerRankingsRepository(
      {required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final ValueNotifier<Map<PlayerRankingsQuery, PlayerRankingsPage>>
      _cachedPages = ValueNotifier(const {});
  final Map<PlayerRankingsQuery, DateTime> _savedAt = {};
  final Map<PlayerRankingsQuery, Future<PlayerRankingsPage>> _inFlightLoads =
      {};
  final Map<PlayerRankingsQuery, Future<PlayerRankingsPage>> _inFlightFetches =
      {};

  @override
  ValueListenable<Map<PlayerRankingsQuery, PlayerRankingsPage>>
      get cachedPages => _cachedPages;

  @override
  PlayerRankingsPage? cachedFor({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  }) =>
      _cachedPages.value[(seasonId: seasonId, limit: limit, offset: offset)];

  @override
  Future<PlayerRankingsPage> load({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  }) async {
    _validate(seasonId, limit, offset);
    final query = (seasonId: seasonId, limit: limit, offset: offset);
    final cached = _cachedPages.value[query];
    if (cached != null) {
      _refreshIfStale(query);
      return cached;
    }
    final inFlight = _inFlightLoads[query];
    if (inFlight != null) return await inFlight;

    late final Future<PlayerRankingsPage> load;
    load = _restoreOrFetch(query).whenComplete(() {
      if (identical(_inFlightLoads[query], load)) _inFlightLoads.remove(query);
    });
    _inFlightLoads[query] = load;
    return await load;
  }

  @override
  Future<PlayerRankingsPage> refresh({
    required int seasonId,
    int limit = 20,
    int offset = 0,
  }) async {
    _validate(seasonId, limit, offset);
    return _fetch((seasonId: seasonId, limit: limit, offset: offset));
  }

  void _validate(int seasonId, int limit, int offset) {
    if (seasonId < 1) {
      throw RangeError.value(seasonId, 'seasonId', 'Must be positive');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (offset < 0) {
      throw RangeError.value(offset, 'offset', 'Must not be negative');
    }
  }

  Future<PlayerRankingsPage> _restoreOrFetch(PlayerRankingsQuery query) async {
    final restored = await _restore(query);
    if (restored != null) {
      _refreshIfStale(query);
      return restored;
    }
    return _fetch(query);
  }

  void _refreshIfStale(PlayerRankingsQuery query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      unawaited(_fetch(query).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<PlayerRankingsPage?> _restore(PlayerRankingsQuery query) async {
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
      final page = _mapPage(decoded, query);
      _publish(query, page, record.savedAt);
      return page;
    } on Object {
      try {
        await store.delete(key);
      } on Object {
        // A damaged cache must not block recovery from the API.
      }
      return null;
    }
  }

  Future<PlayerRankingsPage> _fetch(PlayerRankingsQuery query) {
    final inFlight = _inFlightFetches[query];
    if (inFlight != null) return inFlight;
    late final Future<PlayerRankingsPage> fetch;
    fetch = _fetchAndCache(query).whenComplete(() {
      if (identical(_inFlightFetches[query], fetch)) {
        _inFlightFetches.remove(query);
      }
    });
    _inFlightFetches[query] = fetch;
    return fetch;
  }

  Future<PlayerRankingsPage> _fetchAndCache(PlayerRankingsQuery query) async {
    final uri = _api.baseUri.resolve('players/rankings').replace(
      queryParameters: {
        'season_id': '${query.seasonId}',
        'limit': '${query.limit}',
        'offset': '${query.offset}',
      },
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
    final page = _mapPage(decoded, query);
    _publish(query, page, DateTime.now().toUtc());
    try {
      await _cacheStore?.write(_key(query), decoded);
    } on Object {
      // Storage failure must not hide a valid API response.
    }
    return page;
  }

  PlayerRankingsPage _mapPage(
    Map<String, dynamic> decoded,
    PlayerRankingsQuery query,
  ) {
    final page = playerRankingsFromApiResponse(
        ApiPlayerRankingsResponse.fromJson(decoded));
    if (page.seasonId != query.seasonId ||
        page.limit != query.limit ||
        page.offset != query.offset) {
      throw const FormatException(
        'Player-ranking response does not match the requested page.',
      );
    }
    return page;
  }

  void _publish(
    PlayerRankingsQuery query,
    PlayerRankingsPage page,
    DateTime savedAt,
  ) {
    _savedAt[query] = savedAt;
    _cachedPages.value = Map.unmodifiable({..._cachedPages.value, query: page});
  }

  String _key(PlayerRankingsQuery query) =>
      LocalCacheKeys.playerRankings(query.seasonId, query.limit, query.offset);
}
