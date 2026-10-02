import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/standings/api/api_standing_mapper.dart';
import 'package:onetouch/data/standings/api/api_standing_response.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/standing.dart';

class ApiStandingRepository implements StandingRepository {
  ApiStandingRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<StandingQuery, DateTime> _savedAt = {};
  final ValueNotifier<Map<StandingQuery, List<Standing>>> _cachedTables =
      ValueNotifier(const {});
  final ValueNotifier<List<Standing>> _standings = ValueNotifier(const []);
  final Map<StandingQuery, Future<List<Standing>>> _inFlightLoads = {};
  final Map<StandingQuery, Future<List<Standing>>> _inFlightFetches = {};

  @override
  List<Standing> get allStandings => _standings.value;

  @override
  ValueListenable<List<Standing>> get standings => _standings;

  @override
  ValueListenable<Map<StandingQuery, List<Standing>>> get cachedTables =>
      _cachedTables;

  @override
  List<Standing>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    return _cachedTables
        .value[StandingQuery(competitionId: competitionId, seasonId: seasonId)];
  }

  /// Loads only the local snapshot for startup; never waits for the network.
  Future<List<Standing>?> restoreCachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) async =>
      cachedForCompetition(competitionId, seasonId: seasonId) ??
      await _restore(
        StandingQuery(competitionId: competitionId, seasonId: seasonId),
      );

  @override
  Future<List<Standing>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    final query = StandingQuery(
      competitionId: competitionId,
      seasonId: seasonId,
    );
    final cached = _cachedTables.value[query];
    if (cached != null) {
      _refreshIfStale(query);
      return Future.value(cached);
    }

    final inFlight = _inFlightLoads[query];
    if (inFlight != null) return inFlight;

    late final Future<List<Standing>> load;
    load = _restoreOrFetch(query).whenComplete(() {
      if (identical(_inFlightLoads[query], load)) {
        _inFlightLoads.remove(query);
      }
    });
    _inFlightLoads[query] = load;
    return load;
  }

  @override
  Future<List<Standing>> refreshForCompetition(
    int competitionId, {
    int? seasonId,
  }) =>
      _fetch(StandingQuery(
        competitionId: competitionId,
        seasonId: seasonId,
      ));

  Future<List<Standing>> _restoreOrFetch(StandingQuery query) async {
    final restored = await _restore(query);
    if (restored != null) {
      _refreshIfStale(query);
      return restored;
    }
    return _fetch(query);
  }

  void _refreshIfStale(StandingQuery query) {
    if (!AppCachePolicy.shouldRefresh(
      tier: CacheTier.extended,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      return;
    }
    unawaited(_fetch(query).then<void>((_) {}, onError: (Object _) {}));
  }

  Future<List<Standing>?> _restore(StandingQuery query) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.standings(
      query.competitionId,
      query.seasonId,
    );
    LocalCacheRecord? record;
    try {
      record = await store.read(key);
    } on Object {
      return null;
    }
    if (record == null) return null;

    final alreadyCached = cachedForCompetition(
      query.competitionId,
      seasonId: query.seasonId,
    );
    if (alreadyCached != null) return alreadyCached;

    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final result = _mapAndVerify(decoded, query);
      _publish(query, result.$1, result.$2, record.savedAt);
      return result.$1;
    } on Object {
      try {
        await store.delete(key);
      } on Object {
        // A corrupt or unavailable cache must not block the API request.
      }
      return null;
    }
  }

  Future<List<Standing>> _fetch(StandingQuery query) {
    final inFlight = _inFlightFetches[query];
    if (inFlight != null) return inFlight;

    late final Future<List<Standing>> fetch;
    fetch = _fetchAndCache(query).whenComplete(() {
      if (identical(_inFlightFetches[query], fetch)) {
        _inFlightFetches.remove(query);
      }
    });
    _inFlightFetches[query] = fetch;
    return fetch;
  }

  Future<List<Standing>> _fetchAndCache(StandingQuery query) async {
    final competitionId = query.competitionId;
    final seasonId = query.seasonId;

    final baseUri =
        _api.baseUri.resolve('competitions/$competitionId/standings');
    final uri = seasonId == null
        ? baseUri
        : baseUri.replace(queryParameters: {'season_id': '$seasonId'});
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final result = _mapAndVerify(decoded, query);
    final savedAt = DateTime.now().toUtc();
    _publish(query, result.$1, result.$2, savedAt);
    try {
      await _cacheStore?.write(
        LocalCacheKeys.standings(query.competitionId, query.seasonId),
        decoded,
      );
      if (result.$2 != query) {
        await _cacheStore?.write(
          LocalCacheKeys.standings(
            result.$2.competitionId,
            result.$2.seasonId,
          ),
          decoded,
        );
      }
    } on Object {
      // A cache failure must not hide a valid standings response.
    }
    return result.$1;
  }

  (List<Standing>, StandingQuery) _mapAndVerify(
    Map<String, dynamic> decoded,
    StandingQuery query,
  ) {
    final competitionId = query.competitionId;
    final seasonId = query.seasonId;
    final apiResponse = ApiCompetitionStandingsResponse.fromJson(decoded);
    if (apiResponse.competitionId != competitionId) {
      throw FormatException(
        'Expected competition_id $competitionId but received '
        '${apiResponse.competitionId}.',
      );
    }
    if (seasonId != null && apiResponse.seasonId != seasonId) {
      throw FormatException(
        'Expected season_id $seasonId but received ${apiResponse.seasonId}.',
      );
    }

    final table = standingsFromApiResponse(apiResponse);
    final actualQuery = StandingQuery(
      competitionId: apiResponse.competitionId,
      seasonId: apiResponse.seasonId,
    );
    return (table, actualQuery);
  }

  void _publish(
    StandingQuery query,
    List<Standing> table,
    StandingQuery actualQuery,
    DateTime savedAt,
  ) {
    _cachedTables.value = Map.unmodifiable({
      ..._cachedTables.value,
      query: table,
      actualQuery: table,
    });
    _savedAt[query] = savedAt;
    _savedAt[actualQuery] = savedAt;
    _standings.value = List.unmodifiable(
      _cachedTables.value.values.expand((rows) => rows).toSet().toList(),
    );
  }

  @override
  List<Standing> forCompetition(
    int competitionId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  }) {
    final rows = seasonId == null
        ? cachedForCompetition(competitionId) ??
            _uniqueCompetitionRows(competitionId)
        : cachedForCompetition(competitionId, seasonId: seasonId) ?? const [];
    return List.unmodifiable(rows.where(
      (standing) =>
          (phase == null || standing.phase == phase) &&
          (groupName == null || standing.groupName == groupName),
    ));
  }

  List<Standing> _uniqueCompetitionRows(int competitionId) {
    final unique = <(int, int), Standing>{};
    for (final entry in _cachedTables.value.entries) {
      if (entry.key.competitionId != competitionId) continue;
      for (final standing in entry.value) {
        unique[(standing.seasonId, standing.teamId)] = standing;
      }
    }
    return unique.values.toList(growable: false);
  }

  @override
  Standing? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  }) {
    for (final standing in forCompetition(
      competitionId,
      seasonId: seasonId,
      phase: phase,
      groupName: groupName,
    )) {
      if (standing.teamId == teamId) return standing;
    }
    return null;
  }

  @override
  Future<void> initialize() async {}
}
