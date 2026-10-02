import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_mapper.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_response.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';
import 'package:onetouch/models/team_overview.dart';

class ApiTeamOverviewRepository implements TeamOverviewRepository {
  ApiTeamOverviewRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<int, DateTime> _savedAt = {};
  final ValueNotifier<Map<int, TeamOverview>> _cachedTeams =
      ValueNotifier(const {});
  final Map<int, Future<TeamOverview>> _inFlightLoads = {};
  final Map<int, Future<TeamOverview>> _inFlightFetches = {};

  @override
  ValueListenable<Map<int, TeamOverview>> get cachedTeams => _cachedTeams;

  @override
  TeamOverview? cachedForTeam(int teamId) => _cachedTeams.value[teamId];

  /// Loads only the local snapshot for startup; never waits for the network.
  Future<TeamOverview?> restoreCachedForTeam(int teamId) async =>
      cachedForTeam(teamId) ?? await _restore(teamId);

  @override
  Future<TeamOverview> loadForTeam(int teamId) {
    final cached = cachedForTeam(teamId);
    if (cached != null) {
      _refreshIfStale(teamId);
      return Future.value(cached);
    }

    final inFlight = _inFlightLoads[teamId];
    if (inFlight != null) return inFlight;

    late final Future<TeamOverview> load;
    load = _restoreOrFetch(teamId).whenComplete(() {
      if (identical(_inFlightLoads[teamId], load)) {
        _inFlightLoads.remove(teamId);
      }
    });
    _inFlightLoads[teamId] = load;
    return load;
  }

  Future<TeamOverview> _restoreOrFetch(int teamId) async {
    final restored = await _restore(teamId);
    if (restored != null) {
      _refreshIfStale(teamId);
      return restored;
    }
    return _fetch(teamId);
  }

  void _refreshIfStale(int teamId) {
    if (!AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[teamId],
    )) {
      return;
    }
    unawaited(_fetch(teamId).then<void>((_) {}, onError: (Object _) {}));
  }

  Future<TeamOverview?> _restore(int teamId) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.teamOverview(teamId);
    LocalCacheRecord? record;
    try {
      record = await store.read(key);
    } on Object {
      return null;
    }
    if (record == null) return null;

    final alreadyCached = cachedForTeam(teamId);
    if (alreadyCached != null) return alreadyCached;

    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final overview = _mapAndVerify(decoded, teamId);
      _publish(teamId, overview, record.savedAt);
      return overview;
    } on Object {
      try {
        await store.delete(key);
      } on Object {
        // A corrupt or unavailable cache must not block the API request.
      }
      return null;
    }
  }

  Future<TeamOverview> _fetch(int teamId) {
    final inFlight = _inFlightFetches[teamId];
    if (inFlight != null) return inFlight;

    late final Future<TeamOverview> fetch;
    fetch = _fetchAndCache(teamId).whenComplete(() {
      if (identical(_inFlightFetches[teamId], fetch)) {
        _inFlightFetches.remove(teamId);
      }
    });
    _inFlightFetches[teamId] = fetch;
    return fetch;
  }

  Future<TeamOverview> _fetchAndCache(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final overview = _mapAndVerify(decoded, teamId);
    _publish(teamId, overview, DateTime.now().toUtc());
    try {
      await _cacheStore?.write(LocalCacheKeys.teamOverview(teamId), decoded);
    } on Object {
      // A cache failure must not hide a valid team overview response.
    }
    return overview;
  }

  TeamOverview _mapAndVerify(
    Map<String, dynamic> decoded,
    int teamId,
  ) {
    final overview = teamOverviewFromApiResponse(
      ApiTeamOverviewResponse.fromJson(decoded),
    );
    if (overview.id != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${overview.id}.',
      );
    }
    return overview;
  }

  void _publish(int teamId, TeamOverview overview, DateTime savedAt) {
    _savedAt[teamId] = savedAt;
    _cachedTeams.value = Map.unmodifiable({
      ..._cachedTeams.value,
      teamId: overview,
    });
  }
}
