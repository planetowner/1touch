import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/repository_cache.dart';
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
  late final _cache = RepositoryCache<int, TeamOverview>(
    fetch: _fetch,
    decode: _mapAndVerify,
    keyOf: LocalCacheKeys.teamOverview,
    tier: CacheTier.standard,
    store: _cacheStore,
  );

  @override
  ValueListenable<Map<int, TeamOverview>> get cachedTeams => _cache.values;

  @override
  TeamOverview? cachedForTeam(int teamId) => _cache.cached(teamId);

  Future<TeamOverview?> restoreCachedForTeam(int teamId) =>
      _cache.restore(teamId);

  @override
  Future<TeamOverview> loadForTeam(int teamId, {bool forceRefresh = false}) =>
      _cache.load(teamId, forceRefresh: forceRefresh);

  Future<Map<String, dynamic>> _fetch(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId');
    final response = await _api.get(
      uri,
    );

    return _api.decodeJson<Map<String, dynamic>>(response);
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
}
