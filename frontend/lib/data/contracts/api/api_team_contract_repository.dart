import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/contracts/api/api_team_contract_mapper.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/models/team_contract_roster.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/contracts`.
class ApiTeamContractRepository implements TeamContractRepository {
  ApiTeamContractRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<int, TeamContractRoster>> _cachedRosters =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamContractRoster>> get cachedRosters =>
      _cachedRosters;

  @override
  TeamContractRoster? cachedForTeam(int teamId) => _cachedRosters.value[teamId];

  @override
  Future<TeamContractRoster> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    // The backend's default ordering is ascending by contract end date, with
    // missing end dates last. Screen-specific reordering remains a UI concern.
    final uri = _apiBaseUri.resolve('teams/$teamId/contracts');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Team contracts request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the team contracts response to be a JSON object.',
      );
    }

    final apiResponse = ApiTeamContractsResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }

    final roster = teamContractRosterFromApiResponse(apiResponse);
    _cachedRosters.value = Map.unmodifiable({
      ..._cachedRosters.value,
      teamId: roster,
    });
    return roster;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
