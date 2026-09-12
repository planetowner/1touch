import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/team_attributes/api/api_team_attribute_mapper.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_response.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

/// HTTP implementation of the verified current team-attributes query.
///
/// The deployed endpoint returns one season. Until the backend exposes a
/// reliable list of attribute seasons, this implementation returns only the
/// current response and the Team Analysis comparison picker remains unavailable
/// when this repository is selected.
class ApiTeamAttributeRepository implements TeamAttributeRepository {
  ApiTeamAttributeRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

  @override
  Future<List<TeamAttributeScores>> loadForTeam(int teamId) async {
    final uri = _apiBaseUri.resolve('teams/$teamId/attributes');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Team attributes request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the team attributes response to be a JSON object.',
      );
    }

    final apiResponse = ApiTeamAttributeResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }

    return List.unmodifiable([
      teamAttributeScoresFromApiResponse(apiResponse),
    ]);
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
