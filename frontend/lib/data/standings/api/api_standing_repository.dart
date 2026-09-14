import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/standings/api/api_standing_mapper.dart';
import 'package:onetouch/data/standings/api/api_standing_response.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/standing.dart';

class ApiStandingRepository implements StandingRepository {
  ApiStandingRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<StandingQuery, List<Standing>>> _cachedTables =
      ValueNotifier(const {});
  final ValueNotifier<List<Standing>> _standings = ValueNotifier(const []);

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
  }) async {
    final query = StandingQuery(
      competitionId: competitionId,
      seasonId: seasonId,
    );
    final cached = _cachedTables.value[query];
    if (cached != null) return cached;

    final baseUri =
        _apiBaseUri.resolve('competitions/$competitionId/standings');
    final uri = seasonId == null
        ? baseUri
        : baseUri.replace(queryParameters: {'season_id': '$seasonId'});
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Standings request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the standings response to be a JSON object.',
      );
    }
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

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
