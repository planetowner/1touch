import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/team_probability/api/api_team_probability_mapper.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_response.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_probability.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/probability`.
class ApiTeamProbabilityRepository implements TeamProbabilityRepository {
  ApiTeamProbabilityRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      _cachedSnapshots = ValueNotifier(const {});

  @override
  ValueListenable<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      get cachedSnapshots => _cachedSnapshots;

  @override
  TeamProbabilitySnapshot? cachedForTeam(int teamId, {int? seasonId}) {
    return _cachedSnapshots
        .value[TeamProbabilityQuery(teamId: teamId, seasonId: seasonId)];
  }

  @override
  Future<TeamProbabilitySnapshot> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    final query = TeamProbabilityQuery(teamId: teamId, seasonId: seasonId);
    final cached = _cachedSnapshots.value[query];
    if (cached != null) return cached;

    final uri = _apiBaseUri.resolve('teams/$teamId/probability').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode == 404) {
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Probability',
      );
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Team probability request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the team probability response to be a JSON object.',
      );
    }
    final apiResponse = ApiTeamProbabilityResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }
    if (seasonId != null && apiResponse.seasonId != seasonId) {
      throw FormatException(
        'Expected season_id $seasonId but received ${apiResponse.seasonId}.',
      );
    }

    final snapshot = teamProbabilityFromApiResponse(apiResponse);
    final actualQuery = TeamProbabilityQuery(
      teamId: snapshot.teamId,
      seasonId: snapshot.seasonId,
    );
    _cachedSnapshots.value = Map.unmodifiable({
      ..._cachedSnapshots.value,
      query: snapshot,
      actualQuery: snapshot,
    });
    return snapshot;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
