import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/standings/api/api_standing_mapper.dart';
import 'package:onetouch/data/standings/api/api_standing_response.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/standing.dart';

class ApiStandingRepository implements StandingRepository {
  ApiStandingRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
  final ValueNotifier<Map<StandingQuery, List<Standing>>> _cachedTables =
      ValueNotifier(const {});
  final ValueNotifier<List<Standing>> _standings = ValueNotifier(const []);
  final Map<StandingQuery, Future<List<Standing>>> _inFlightLoads = {};

  @override
  List<Standing> get allStandings => _standings.value;

  @override
  ValueListenable<List<Standing>> get standings => _standings;

  @override
  ValueListenable<Map<StandingQuery, List<Standing>>> get cachedTables =>
      _cachedTables;

  @override
  List<Standing>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    return _cachedTables
        .value[StandingQuery(competitionId: competitionId, seasonId: seasonId)];
  }

  @override
  Future<List<Standing>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    final query = StandingQuery(
      competitionId: competitionId,
      seasonId: seasonId,
    );
    final cached = _cachedTables.value[query];
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlightLoads[query];
    if (inFlight != null) return inFlight;

    late final Future<List<Standing>> load;
    load = _fetchAndCache(query).whenComplete(() {
      if (identical(_inFlightLoads[query], load)) {
        _inFlightLoads.remove(query);
      }
    });
    _inFlightLoads[query] = load;
    return load;
  }

  Future<List<Standing>> _fetchAndCache(StandingQuery query) async {
    final competitionId = query.competitionId;
    final seasonId = query.seasonId;

    final baseUri =
        _api.baseUri.resolve('competitions/$competitionId/standings');
    final uri = seasonId == null
        ? baseUri
        : baseUri.replace(queryParameters: {'season_id': '$seasonId'});
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final apiResponse = ApiCompetitionStandingsResponse.fromJson(decoded);
    if (apiResponse.competitionId != competitionId) {
      throw FormatException(
        'Expected competition_id $competitionId but received '
        '${apiResponse.competitionId}.',
      );
    }
    if (seasonId != null && apiResponse.seasonId != seasonId) {
      throw FormatException(
        'Expected season_id $seasonId but received ${apiResponse.seasonId}.',
      );
    }

    final table = standingsFromApiResponse(apiResponse);
    final actualQuery = StandingQuery(
      competitionId: apiResponse.competitionId,
      seasonId: apiResponse.seasonId,
    );
    _cachedTables.value = Map.unmodifiable({
      ..._cachedTables.value,
      query: table,
      actualQuery: table,
    });
    _standings.value = List.unmodifiable(
      _cachedTables.value.values.expand((rows) => rows).toSet().toList(),
    );
    return table;
  }

  @override
  List<Standing> forCompetition(
    int competitionId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  }) {
    final rows = seasonId == null
        ? cachedForCompetition(competitionId) ??
            _uniqueCompetitionRows(competitionId)
        : cachedForCompetition(competitionId, seasonId: seasonId) ?? const [];
    return List.unmodifiable(rows.where(
      (standing) =>
          (phase == null || standing.phase == phase) &&
          (groupName == null || standing.groupName == groupName),
    ));
  }

  List<Standing> _uniqueCompetitionRows(int competitionId) {
    final unique = <(int, int), Standing>{};
    for (final entry in _cachedTables.value.entries) {
      if (entry.key.competitionId != competitionId) continue;
      for (final standing in entry.value) {
        unique[(standing.seasonId, standing.teamId)] = standing;
      }
    }
    return unique.values.toList(growable: false);
  }

  @override
  Standing? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
    StandingPhase? phase,
    String? groupName,
  }) {
    for (final standing in forCompetition(
      competitionId,
      seasonId: seasonId,
      phase: phase,
      groupName: groupName,
    )) {
      if (standing.teamId == teamId) return standing;
    }
    return null;
  }

  @override
  Future<void> initialize() async {}
}
