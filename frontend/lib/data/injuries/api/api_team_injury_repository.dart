import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_mapper.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_response.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_injury_report.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/injuries`.
class ApiTeamInjuryRepository implements TeamInjuryRepository {
  ApiTeamInjuryRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
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

    final uri = _api.baseUri.resolve('teams/$teamId/injuries');
    final response = await _api.get(
      uri,
    );
    if (response.statusCode == 404) {
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Injuries',
      );
    }

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);

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
}
