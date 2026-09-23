import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_mapper.dart';
import 'package:onetouch/data/team_probability/api/api_team_probability_response.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_probability.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/probability`.
class ApiTeamProbabilityRepository implements TeamProbabilityRepository {
  ApiTeamProbabilityRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
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

    final uri = _api.baseUri.resolve('teams/$teamId/probability').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final response = await _api.get(
      uri,
    );
    if (response.statusCode == 404) {
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Probability',
      );
    }

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
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
}
