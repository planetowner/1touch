import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_mapper.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/models/team_contract_roster.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/contracts`.
class ApiTeamContractRepository implements TeamContractRepository {
  ApiTeamContractRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
  final ValueNotifier<Map<TeamContractQuery, TeamContractRoster>>
      _cachedRosters = ValueNotifier(const {});

  @override
  ValueListenable<Map<TeamContractQuery, TeamContractRoster>>
      get cachedRosters => _cachedRosters;

  @override
  TeamContractRoster? cachedForTeam(
    int teamId, {
    int? seasonId,
  }) {
    return _cachedRosters.value[TeamContractQuery(
      teamId: teamId,
      seasonId: seasonId,
    )];
  }

  @override
  Future<TeamContractRoster> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    final query = TeamContractQuery(teamId: teamId, seasonId: seasonId);
    final cached = _cachedRosters.value[query];
    if (cached != null) return cached;

    // The backend's default ordering is ascending by contract end date, with
    // missing end dates last. Screen-specific reordering remains a UI concern.
    final uri = _api.baseUri.resolve('teams/$teamId/contracts').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
      },
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);

    final apiResponse = ApiTeamContractsResponse.fromJson(decoded);
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

    final roster = teamContractRosterFromApiResponse(apiResponse);
    _cachedRosters.value = Map.unmodifiable({
      ..._cachedRosters.value,
      query: roster,
    });
    return roster;
  }
}
