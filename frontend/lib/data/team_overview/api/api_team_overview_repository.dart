import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_mapper.dart';
import 'package:onetouch/data/team_overview/api/api_team_overview_response.dart';
import 'package:onetouch/data/team_overview/team_overview_repository.dart';
import 'package:onetouch/models/team_overview.dart';

class ApiTeamOverviewRepository implements TeamOverviewRepository {
  ApiTeamOverviewRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
  final ValueNotifier<Map<int, TeamOverview>> _cachedTeams =
      ValueNotifier(const {});
  final Map<int, Future<TeamOverview>> _inFlightLoads = {};

  @override
  ValueListenable<Map<int, TeamOverview>> get cachedTeams => _cachedTeams;

  @override
  TeamOverview? cachedForTeam(int teamId) => _cachedTeams.value[teamId];

  @override
  Future<TeamOverview> loadForTeam(int teamId) {
    final cached = cachedForTeam(teamId);
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlightLoads[teamId];
    if (inFlight != null) return inFlight;

    late final Future<TeamOverview> load;
    load = _fetchAndCache(teamId).whenComplete(() {
      if (identical(_inFlightLoads[teamId], load)) {
        _inFlightLoads.remove(teamId);
      }
    });
    _inFlightLoads[teamId] = load;
    return load;
  }

  Future<TeamOverview> _fetchAndCache(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId');
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);

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
}
