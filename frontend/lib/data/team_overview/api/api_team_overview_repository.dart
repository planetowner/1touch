import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/team_overview/api/api_team_overview_mapper.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_response.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';
import 'package:onetouch/models/team_overview.dart';

class ApiTeamOverviewRepository implements TeamOverviewRepository {
  ApiTeamOverviewRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<int, TeamOverview>> _cachedTeams =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamOverview>> get cachedTeams => _cachedTeams;

  @override
  TeamOverview? cachedForTeam(int teamId) => _cachedTeams.value[teamId];

  @override
  Future<TeamOverview> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    final uri = _apiBaseUri.resolve('teams/$teamId');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Team overview request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the Team overview response to be a JSON object.',
      );
    }

    final overview = teamOverviewFromApiResponse(
      ApiTeamOverviewResponse.fromJson(decoded),
    );
    if (overview.id != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${overview.id}.',
      );
    }

    _cachedTeams.value = Map.unmodifiable({
      ..._cachedTeams.value,
      teamId: overview,
    });
    return overview;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
