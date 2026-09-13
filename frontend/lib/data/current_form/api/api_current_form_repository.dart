import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/current_form/api/api_current_form_mapper.dart';
import 'package:onetouch/data/current_form/api/api_current_form_response.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/models/current_form.dart';

/// HTTP implementation of the Current Form options and comparison endpoints.
class ApiCurrentFormRepository implements CurrentFormRepository {
  ApiCurrentFormRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
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
        _apiBaseUri.resolve('teams/$teamId/current-form/options').replace(
      queryParameters: {
        if (query.search.isNotEmpty) 'search': query.search,
        'limit': '$limit',
      },
    );
    final decoded = await _getJsonObject(uri, 'Current Form options');
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

    final uri = _apiBaseUri.resolve('teams/$teamId/current-form').replace(
      queryParameters: {
        'compare_team_id': '$compareTeamId',
        'compare_season_id': '$compareSeasonId',
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final httpResponse = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (httpResponse.statusCode != 200) {
      throw http.ClientException(
        'Current Form request failed with status '
        '${httpResponse.statusCode}.',
        uri,
      );
    }

    final decoded = _decodeJsonObject(httpResponse.body, 'Current Form');
    final response = ApiCurrentFormResponse.fromJson(decoded);
    _verifyComparisonResponse(response, query);

    final comparison = currentFormComparisonFromApiResponse(response);
    _cachedComparisons.value = Map.unmodifiable({
      ..._cachedComparisons.value,
      query: comparison,
    });
    return comparison;
  }

  Future<Map<String, dynamic>> _getJsonObject(
    Uri uri,
    String responseName,
  ) async {
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        '$responseName request failed with status ${response.statusCode}.',
        uri,
      );
    }
    return _decodeJsonObject(response.body, responseName);
  }

  static Map<String, dynamic> _decodeJsonObject(
    String body,
    String responseName,
  ) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected the $responseName response to be a JSON object.',
      );
    }
    return decoded;
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

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
