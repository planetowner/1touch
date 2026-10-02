import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_mapper.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_response.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/models/standing.dart';

class ApiXgStandingRepository implements XgStandingRepository {
  ApiXgStandingRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<XgStandingQuery, DateTime> _savedAt = {};
  final ValueNotifier<Map<XgStandingQuery, List<XgStanding>>> _cachedTables =
      ValueNotifier(const {});
  final ValueNotifier<List<XgStanding>> _xgStandings = ValueNotifier(const []);
  final Map<XgStandingQuery, Future<List<XgStanding>>> _inFlightLoads = {};
  final Map<XgStandingQuery, Future<List<XgStanding>>> _inFlightFetches = {};

  @override
  List<XgStanding> get allXgStandings => _xgStandings.value;

  @override
  ValueListenable<List<XgStanding>> get xgStandings => _xgStandings;

  @override
  ValueListenable<Map<XgStandingQuery, List<XgStanding>>> get cachedTables =>
      _cachedTables;

  @override
  List<XgStanding>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    return _cachedTables.value[
        XgStandingQuery(competitionId: competitionId, seasonId: seasonId)];
  }

  @override
  Future<List<XgStanding>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    final query = XgStandingQuery(
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

    late final Future<List<XgStanding>> load;
    load = _restoreOrFetch(query).whenComplete(() {
      if (identical(_inFlightLoads[query], load)) {
        _inFlightLoads.remove(query);
      }
    });
    _inFlightLoads[query] = load;
    return load;
  }

  @override
  Future<List<XgStanding>> refreshForCompetition(
    int competitionId, {
    int? seasonId,
  }) =>
      _fetch(XgStandingQuery(
        competitionId: competitionId,
        seasonId: seasonId,
      ));

  Future<List<XgStanding>> _restoreOrFetch(XgStandingQuery query) async {
    final restored = await _restore(query);
    if (restored != null) {
      _refreshIfStale(query);
      return restored;
    }
    return _fetch(query);
  }

  void _refreshIfStale(XgStandingQuery query) {
    if (!AppCachePolicy.shouldRefresh(
      tier: CacheTier.extended,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      return;
    }
    unawaited(_fetch(query).then<void>((_) {}, onError: (Object _) {}));
  }

  Future<List<XgStanding>?> _restore(XgStandingQuery query) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.xgStandings(
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

  Future<List<XgStanding>> _fetch(XgStandingQuery query) {
    final inFlight = _inFlightFetches[query];
    if (inFlight != null) return inFlight;

    late final Future<List<XgStanding>> fetch;
    fetch = _fetchAndCache(query).whenComplete(() {
      if (identical(_inFlightFetches[query], fetch)) {
        _inFlightFetches.remove(query);
      }
    });
    _inFlightFetches[query] = fetch;
    return fetch;
  }

  Future<List<XgStanding>> _fetchAndCache(XgStandingQuery query) async {
    final competitionId = query.competitionId;
    final seasonId = query.seasonId;

    final baseUri =
        _api.baseUri.resolve('competitions/$competitionId/xg-standings');
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
        LocalCacheKeys.xgStandings(query.competitionId, query.seasonId),
        decoded,
      );
      if (result.$2 != query) {
        await _cacheStore?.write(
          LocalCacheKeys.xgStandings(
            result.$2.competitionId,
            result.$2.seasonId,
          ),
          decoded,
        );
      }
    } on Object {
      // A cache failure must not hide a valid xG standings response.
    }
    return result.$1;
  }

  (List<XgStanding>, XgStandingQuery) _mapAndVerify(
    Map<String, dynamic> decoded,
    XgStandingQuery query,
  ) {
    final competitionId = query.competitionId;
    final seasonId = query.seasonId;
    final apiResponse = ApiCompetitionXgStandingsResponse.fromJson(decoded);
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

    final table = xgStandingsFromApiResponse(apiResponse);
    final actualQuery = XgStandingQuery(
      competitionId: apiResponse.competitionId,
      seasonId: apiResponse.seasonId,
    );
    return (table, actualQuery);
  }

  void _publish(
    XgStandingQuery query,
    List<XgStanding> table,
    XgStandingQuery actualQuery,
    DateTime savedAt,
  ) {
    _cachedTables.value = Map.unmodifiable({
      ..._cachedTables.value,
      query: table,
      actualQuery: table,
    });
    _savedAt[query] = savedAt;
    _savedAt[actualQuery] = savedAt;
    _xgStandings.value = List.unmodifiable(
      _cachedTables.value.values.expand((rows) => rows).toSet().toList(),
    );
  }

  @override
  List<XgStanding> forCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    final rows = seasonId == null
        ? cachedForCompetition(competitionId) ??
            _uniqueCompetitionRows(competitionId)
        : cachedForCompetition(competitionId, seasonId: seasonId) ?? const [];
    return List.unmodifiable(rows);
  }

  List<XgStanding> _uniqueCompetitionRows(int competitionId) {
    final unique = <(int, int), XgStanding>{};
    for (final entry in _cachedTables.value.entries) {
      if (entry.key.competitionId != competitionId) continue;
      for (final standing in entry.value) {
        unique[(standing.seasonId, standing.teamId)] = standing;
      }
    }
    return unique.values.toList(growable: false);
  }

  @override
  XgStanding? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
  }) {
    for (final standing in forCompetition(
      competitionId,
      seasonId: seasonId,
    )) {
      if (standing.teamId == teamId) return standing;
    }
    return null;
  }

  @override
  Future<void> initialize() async {}
}
