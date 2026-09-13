import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/team_attributes/api/api_team_attribute_options_mapper.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_options_response.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_mapper.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_response.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';

/// HTTP implementation of the verified team-attributes query.
///
/// The deployed endpoint returns one season per request. Omitting `season_id`
/// selects the current season; supplying it selects that historical season.
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
  Future<List<TeamAttributeSeasonOption>> loadOptionsForTeam(int teamId) async {
    final uri = _apiBaseUri.resolve('teams/$teamId/attributes/options');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Team attribute options request failed with status '
        '${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the team attribute options response to be a JSON object.',
      );
    }

    final apiResponse = ApiTeamAttributeOptionsResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }
    return teamAttributeOptionsFromApiResponse(apiResponse);
  }

  @override
  Future<List<TeamAttributeScores>> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    final uri = _apiBaseUri.resolve('teams/$teamId/attributes').replace(
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
    if (seasonId != null && apiResponse.seasonId != seasonId) {
      throw FormatException(
        'Expected season_id $seasonId but received ${apiResponse.seasonId}.',
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
