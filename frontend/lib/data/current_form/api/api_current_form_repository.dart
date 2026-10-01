import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/current_form/api/api_current_form_mapper.dart';
import 'package:onetouch/data/current_form/api/api_current_form_response.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/current_form.dart';

/// HTTP implementation of the Current Form options and comparison endpoints.
class ApiCurrentFormRepository implements CurrentFormRepository {
  ApiCurrentFormRepository({
    required ApiClient api,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final Map<CurrentFormOptionsQuery, DateTime> _optionsSavedAt = {};
  final Map<int, List<CurrentFormOption>> _allOptions = {};
  final Map<int, DateTime> _allOptionsSavedAt = {};
  final Map<CurrentFormComparisonQuery, DateTime> _comparisonsSavedAt = {};
  final ValueNotifier<Map<CurrentFormOptionsQuery, List<CurrentFormOption>>>
      _cachedOptions = ValueNotifier(const {});
  final ValueNotifier<Map<CurrentFormComparisonQuery, CurrentFormComparison>>
      _cachedComparisons = ValueNotifier(const {});

  @override
  ValueListenable<Map<CurrentFormOptionsQuery, List<CurrentFormOption>>>
      get cachedOptions => _cachedOptions;

  @override
  ValueListenable<Map<CurrentFormComparisonQuery, CurrentFormComparison>>
      get cachedComparisons => _cachedComparisons;

  @override
  List<CurrentFormOption>? cachedOptionsFor(
    int teamId, {
    String search = '',
    int limit = 200,
  }) {
    return _cachedOptions.value[CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
      limit: limit,
    )];
  }

  @override
  CurrentFormComparison? cachedComparisonFor(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  }) {
    return _cachedComparisons.value[CurrentFormComparisonQuery(
      teamId: teamId,
      seasonId: seasonId,
      compareTeamId: compareTeamId,
      compareSeasonId: compareSeasonId,
    )];
  }

  @override
  Future<List<CurrentFormOption>> loadOptions(
    int teamId, {
    String search = '',
    int limit = 200,
  }) async {
    if (limit < 1 || limit > 1000) {
      throw RangeError.range(limit, 1, 1000, 'limit');
    }

    final query = CurrentFormOptionsQuery(
      teamId: teamId,
      search: search,
      limit: limit,
    );
    final cached = _cachedOptions.value[query];
    if (cached != null) {
      _refreshOptionsIfStale(query);
      return cached;
    }
    final restored = await _restoreOptions(query);
    if (restored != null) {
      _refreshOptionsIfStale(query);
      return restored;
    }
    return _fetchOptions(query);
  }

  @override
  Future<List<CurrentFormOption>> loadAllOptions(int teamId) async {
    final cached = _allOptions[teamId];
    if (cached != null &&
        !AppCachePolicy.shouldRefresh(
          tier: CacheTier.standard,
          trigger: CacheSyncTrigger.screenEnter,
          savedAt: _allOptionsSavedAt[teamId],
        )) {
      return cached;
    }

    const pageSize = 200;
    final firstQuery = CurrentFormOptionsQuery(teamId: teamId, limit: pageSize);
    final freshFirstPage = _cachedOptions.value[firstQuery];
    final firstPage = freshFirstPage != null &&
            !AppCachePolicy.shouldRefresh(
              tier: CacheTier.standard,
              trigger: CacheSyncTrigger.screenEnter,
              savedAt: _optionsSavedAt[firstQuery],
            )
        ? freshFirstPage
        : await _fetchOptions(firstQuery);
    final all = <CurrentFormOption>[...firstPage];
    while (all.isNotEmpty && all.length % pageSize == 0) {
      final uri = _api.baseUri
          .resolve('teams/$teamId/current-form/options')
          .replace(queryParameters: {
        'limit': '$pageSize',
        'offset': '${all.length}',
      });
      final decoded =
          _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
      final page = _mapOptions(
        decoded,
        CurrentFormOptionsQuery(teamId: teamId, limit: pageSize),
      );
      all.addAll(page);
      if (page.length < pageSize) break;
    }
    _allOptionsSavedAt[teamId] = DateTime.now().toUtc();
    return _allOptions[teamId] = List.unmodifiable(all);
  }

  void _refreshOptionsIfStale(CurrentFormOptionsQuery query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _optionsSavedAt[query],
    )) {
      unawaited(
        _fetchOptions(query).catchError((_) => _cachedOptions.value[query]!),
      );
    }
  }

  Future<List<CurrentFormOption>?> _restoreOptions(
    CurrentFormOptionsQuery query,
  ) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.currentFormOptions(
      query.teamId,
      query.search,
      query.limit,
    );
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final options = _mapOptions(decoded, query);
      _publishOptions(query, options, record.savedAt);
      return options;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<List<CurrentFormOption>> _fetchOptions(
    CurrentFormOptionsQuery query,
  ) async {
    final teamId = query.teamId;
    final limit = query.limit;

    final uri =
        _api.baseUri.resolve('teams/$teamId/current-form/options').replace(
      queryParameters: {
        if (query.search.isNotEmpty) 'search': query.search,
        'limit': '$limit',
      },
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
    final options = _mapOptions(decoded, query);
    _publishOptions(query, options, DateTime.now().toUtc());
    await _cacheStore?.write(
      LocalCacheKeys.currentFormOptions(teamId, query.search, limit),
      decoded,
    );
    return options;
  }

  List<CurrentFormOption> _mapOptions(
    Map<String, dynamic> decoded,
    CurrentFormOptionsQuery query,
  ) {
    final response = ApiCurrentFormOptionsResponse.fromJson(decoded);
    if (response.limit != query.limit) {
      throw FormatException(
        'Expected limit ${query.limit} but received ${response.limit}.',
      );
    }
    return currentFormOptionsFromApiResponse(response);
  }

  void _publishOptions(
    CurrentFormOptionsQuery query,
    List<CurrentFormOption> options,
    DateTime savedAt,
  ) {
    _cachedOptions.value = Map.unmodifiable({
      ..._cachedOptions.value,
      query: options,
    });
    _optionsSavedAt[query] = savedAt;
  }

  @override
  Future<CurrentFormComparison?> loadComparison(
    int teamId, {
    int? seasonId,
    required int compareTeamId,
    required int compareSeasonId,
  }) async {
    final query = CurrentFormComparisonQuery(
      teamId: teamId,
      seasonId: seasonId,
      compareTeamId: compareTeamId,
      compareSeasonId: compareSeasonId,
    );
    final cached = _cachedComparisons.value[query];
    if (cached != null) {
      _refreshComparisonIfStale(query);
      return cached;
    }
    final restored = await _restoreComparison(query);
    if (restored != null) {
      _refreshComparisonIfStale(query);
      return restored;
    }
    return _fetchComparison(query);
  }

  void _refreshComparisonIfStale(CurrentFormComparisonQuery query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.standard,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _comparisonsSavedAt[query],
    )) {
      unawaited(
        _fetchComparison(query)
            .catchError((_) => _cachedComparisons.value[query]),
      );
    }
  }

  Future<CurrentFormComparison?> _restoreComparison(
    CurrentFormComparisonQuery query,
  ) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.currentFormComparison(
      query.teamId,
      query.seasonId,
      query.compareTeamId,
      query.compareSeasonId,
    );
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final comparison = _mapComparison(decoded, query);
      _publishComparison(query, comparison, record.savedAt);
      return comparison;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<CurrentFormComparison?> _fetchComparison(
    CurrentFormComparisonQuery query,
  ) async {
    final teamId = query.teamId;
    final seasonId = query.seasonId;
    final compareTeamId = query.compareTeamId;
    final compareSeasonId = query.compareSeasonId;

    final uri = _api.baseUri.resolve('teams/$teamId/current-form').replace(
      queryParameters: {
        'compare_team_id': '$compareTeamId',
        'compare_season_id': '$compareSeasonId',
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final httpResponse = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(httpResponse);
    final comparison = _mapComparison(decoded, query);
    _publishComparison(query, comparison, DateTime.now().toUtc());
    await _cacheStore?.write(
      LocalCacheKeys.currentFormComparison(
        teamId,
        seasonId,
        compareTeamId,
        compareSeasonId,
      ),
      decoded,
    );
    return comparison;
  }

  CurrentFormComparison _mapComparison(
    Map<String, dynamic> decoded,
    CurrentFormComparisonQuery query,
  ) {
    final response = ApiCurrentFormResponse.fromJson(decoded);
    _verifyComparisonResponse(response, query);
    return currentFormComparisonFromApiResponse(response);
  }

  void _publishComparison(
    CurrentFormComparisonQuery query,
    CurrentFormComparison comparison,
    DateTime savedAt,
  ) {
    _cachedComparisons.value = Map.unmodifiable({
      ..._cachedComparisons.value,
      query: comparison,
    });
    _comparisonsSavedAt[query] = savedAt;
  }

  static void _verifyComparisonResponse(
    ApiCurrentFormResponse response,
    CurrentFormComparisonQuery query,
  ) {
    if (response.current.teamId != query.teamId) {
      throw FormatException(
        'Expected current team_id ${query.teamId} but received '
        '${response.current.teamId}.',
      );
    }
    if (query.seasonId != null && response.current.seasonId != query.seasonId) {
      throw FormatException(
        'Expected current season_id ${query.seasonId} but received '
        '${response.current.seasonId}.',
      );
    }
    if (response.comparison.teamId != query.compareTeamId) {
      throw FormatException(
        'Expected comparison team_id ${query.compareTeamId} but received '
        '${response.comparison.teamId}.',
      );
    }
    if (response.comparison.seasonId != query.compareSeasonId) {
      throw FormatException(
        'Expected comparison season_id ${query.compareSeasonId} but received '
        '${response.comparison.seasonId}.',
      );
    }
  }
}
