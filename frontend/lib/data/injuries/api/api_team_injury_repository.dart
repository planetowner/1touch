import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/injuries/api/api_team_injury_mapper.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_response.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_injury_report.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/injuries`.
class ApiTeamInjuryRepository implements TeamInjuryRepository {
  ApiTeamInjuryRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<int, TeamInjuryReport>> _cachedReports =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamInjuryReport>> get cachedReports =>
      _cachedReports;

  @override
  TeamInjuryReport? cachedForTeam(int teamId) => _cachedReports.value[teamId];

  @override
  Future<TeamInjuryReport> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    final uri = _apiBaseUri.resolve('teams/$teamId/injuries');
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
        feature: 'Injuries',
      );
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Team injuries request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the team injuries response to be a JSON object.',
      );
    }

    final apiResponse = ApiTeamInjuriesResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }

    final report = teamInjuryReportFromApiResponse(apiResponse);
    _cachedReports.value = Map.unmodifiable({
      ..._cachedReports.value,
      teamId: report,
    });
    return report;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
