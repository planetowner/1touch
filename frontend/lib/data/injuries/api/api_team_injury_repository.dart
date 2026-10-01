import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_mapper.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_response.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_injury_report.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/injuries`.
class ApiTeamInjuryRepository implements TeamInjuryRepository {
  ApiTeamInjuryRepository({required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<int, DateTime> _savedAt = {};
  final Map<int, Future<TeamInjuryReport>> _inFlightLoads = {};
  final Map<int, Future<TeamInjuryReport>> _inFlightFetches = {};
  final ValueNotifier<Map<int, TeamInjuryReport>> _cachedReports =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamInjuryReport>> get cachedReports =>
      _cachedReports;

  @override
  TeamInjuryReport? cachedForTeam(int teamId) => _cachedReports.value[teamId];

  @override
  Future<TeamInjuryReport> loadForTeam(int teamId) {
    final cached = cachedForTeam(teamId);
    if (cached != null) {
      _refreshIfStale(teamId);
      return Future.value(cached);
    }

    final inFlight = _inFlightLoads[teamId];
    if (inFlight != null) return inFlight;

    late final Future<TeamInjuryReport> load;
    load = _restoreOrFetch(teamId).whenComplete(() {
      if (identical(_inFlightLoads[teamId], load)) {
        _inFlightLoads.remove(teamId);
      }
    });
    _inFlightLoads[teamId] = load;
    return load;
  }

  Future<TeamInjuryReport> _restoreOrFetch(int teamId) async {
    final restored = await _restore(teamId);
    if (restored != null) {
      _refreshIfStale(teamId);
      return restored;
    }
    return _fetch(teamId);
  }

  void _refreshIfStale(int teamId) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[teamId],
    )) {
      unawaited(_fetch(teamId).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<TeamInjuryReport?> _restore(int teamId) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.teamInjuries(teamId);
    LocalCacheRecord? record;
    try {
      record = await store.read(key);
    } on Object {
      return null;
    }
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final report = _mapAndVerify(decoded, teamId);
      _publish(teamId, report, record.savedAt);
      return report;
    } on Object {
      try {
        await store.delete(key);
      } on Object {
        // A corrupt or unavailable cache must not block the API request.
      }
      return null;
    }
  }

  Future<TeamInjuryReport> _fetch(int teamId) {
    final inFlight = _inFlightFetches[teamId];
    if (inFlight != null) return inFlight;

    late final Future<TeamInjuryReport> fetch;
    fetch = _fetchAndCache(teamId).whenComplete(() {
      if (identical(_inFlightFetches[teamId], fetch)) {
        _inFlightFetches.remove(teamId);
      }
    });
    _inFlightFetches[teamId] = fetch;
    return fetch;
  }

  Future<TeamInjuryReport> _fetchAndCache(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId/injuries');
    final response = await _api.get(
      uri,
    );
    if (response.statusCode == 404) {
      _savedAt.remove(teamId);
      _cachedReports.value =
          Map.unmodifiable({..._cachedReports.value}..remove(teamId));
      try {
        await _cacheStore?.delete(LocalCacheKeys.teamInjuries(teamId));
      } on Object {
        // The server result remains authoritative if local storage is down.
      }
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Injuries',
      );
    }

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final report = _mapAndVerify(decoded, teamId);
    _publish(teamId, report, DateTime.now().toUtc());
    try {
      await _cacheStore?.write(LocalCacheKeys.teamInjuries(teamId), decoded);
    } on Object {
      // A cache failure must not hide a valid injury response.
    }
    return report;
  }

  TeamInjuryReport _mapAndVerify(Map<String, dynamic> decoded, int teamId) {
    final apiResponse = ApiTeamInjuriesResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }

    return teamInjuryReportFromApiResponse(apiResponse);
  }

  void _publish(int teamId, TeamInjuryReport report, DateTime savedAt) {
    _savedAt[teamId] = savedAt;
    _cachedReports.value = Map.unmodifiable({
      ..._cachedReports.value,
      teamId: report,
    });
  }
}
