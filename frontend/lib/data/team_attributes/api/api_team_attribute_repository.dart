import 'package:onetouch/core/api_client.dart';
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
  ApiTeamAttributeRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<List<TeamAttributeSeasonOption>> loadOptionsForTeam(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId/attributes/options');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);

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
    final uri = _api.baseUri.resolve('teams/$teamId/attributes').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);

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
}
