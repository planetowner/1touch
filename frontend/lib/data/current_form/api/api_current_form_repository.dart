import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/current_form/api/api_current_form_mapper.dart';
import 'package:onetouch/data/current_form/api/api_current_form_response.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/models/current_form.dart';

/// HTTP implementation of the Current Form options and comparison endpoints.
class ApiCurrentFormRepository implements CurrentFormRepository {
  ApiCurrentFormRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
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
    if (cached != null) return cached;

    final uri =
        _api.baseUri.resolve('teams/$teamId/current-form/options').replace(
      queryParameters: {
        if (query.search.isNotEmpty) 'search': query.search,
        'limit': '$limit',
      },
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
    final response = ApiCurrentFormOptionsResponse.fromJson(decoded);
    if (response.limit != limit) {
      throw FormatException(
        'Expected limit $limit but received ${response.limit}.',
      );
    }

    final options = currentFormOptionsFromApiResponse(response);
    _cachedOptions.value = Map.unmodifiable({
      ..._cachedOptions.value,
      query: options,
    });
    return options;
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
    if (cached != null) return cached;

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
    final response = ApiCurrentFormResponse.fromJson(decoded);
    _verifyComparisonResponse(response, query);

    final comparison = currentFormComparisonFromApiResponse(response);
    _cachedComparisons.value = Map.unmodifiable({
      ..._cachedComparisons.value,
      query: comparison,
    });
    return comparison;
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
