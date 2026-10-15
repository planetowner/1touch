import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_mapper.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_response.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/repository_cache.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_injury_report.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/injuries`.
class ApiTeamInjuryRepository implements TeamInjuryRepository {
  ApiTeamInjuryRepository({required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  late final _cache = RepositoryCache<int, TeamInjuryReport>(
    fetch: _fetch,
    decode: _mapAndVerify,
    keyOf: LocalCacheKeys.teamInjuries,
    tier: CacheTier.standard,
    store: _cacheStore,
  );

  @override
  ValueListenable<Map<int, TeamInjuryReport>> get cachedReports =>
      _cache.values;

  @override
  TeamInjuryReport? cachedForTeam(int teamId) => _cache.cached(teamId);

  @override
  Future<TeamInjuryReport> loadForTeam(int teamId,
          {bool forceRefresh = false}) =>
      _cache.load(teamId, forceRefresh: forceRefresh);

  Future<Map<String, dynamic>> _fetch(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId/injuries');
    final response = await _api.get(
      uri,
    );
    if (response.statusCode == 404) {
      await _cache.remove(teamId);
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Injuries',
      );
    }

    return _api.decodeJson<Map<String, dynamic>>(response);
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
}
