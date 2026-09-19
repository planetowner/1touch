import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/standings/api/api_xg_standing_mapper.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_response.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';
import 'package:onetouch/models/standing.dart';

class ApiXgStandingRepository implements XgStandingRepository {
  ApiXgStandingRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<XgStandingQuery, List<XgStanding>>> _cachedTables =
      ValueNotifier(const {});
  final ValueNotifier<List<XgStanding>> _xgStandings = ValueNotifier(const []);
  final Map<XgStandingQuery, Future<List<XgStanding>>> _inFlightLoads = {};

  @override
  List<XgStanding> get allXgStandings => _xgStandings.value;

  @override
  ValueListenable<List<XgStanding>> get xgStandings => _xgStandings;

  @override
  ValueListenable<Map<XgStandingQuery, List<XgStanding>>> get cachedTables =>
      _cachedTables;

  @override
  List<XgStanding>? cachedForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    return _cachedTables.value[
        XgStandingQuery(competitionId: competitionId, seasonId: seasonId)];
  }

  @override
  Future<List<XgStanding>> loadForCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    final query = XgStandingQuery(
      competitionId: competitionId,
      seasonId: seasonId,
    );
    final cached = _cachedTables.value[query];
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlightLoads[query];
    if (inFlight != null) return inFlight;

    late final Future<List<XgStanding>> load;
    load = _fetchAndCache(query).whenComplete(() {
      if (identical(_inFlightLoads[query], load)) {
        _inFlightLoads.remove(query);
      }
    });
    _inFlightLoads[query] = load;
    return load;
  }

  Future<List<XgStanding>> _fetchAndCache(XgStandingQuery query) async {
    final competitionId = query.competitionId;
    final seasonId = query.seasonId;

    final baseUri =
        _apiBaseUri.resolve('competitions/$competitionId/xg-standings');
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
        'xG standings request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the xG standings response to be a JSON object.',
      );
    }
    final apiResponse = ApiCompetitionXgStandingsResponse.fromJson(decoded);
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

    final table = xgStandingsFromApiResponse(apiResponse);
    final actualQuery = XgStandingQuery(
      competitionId: apiResponse.competitionId,
      seasonId: apiResponse.seasonId,
    );
    _cachedTables.value = Map.unmodifiable({
      ..._cachedTables.value,
      query: table,
      actualQuery: table,
    });
    _xgStandings.value = List.unmodifiable(
      _cachedTables.value.values.expand((rows) => rows).toSet().toList(),
    );
    return table;
  }

  @override
  List<XgStanding> forCompetition(
    int competitionId, {
    int? seasonId,
  }) {
    final rows = seasonId == null
        ? cachedForCompetition(competitionId) ??
            _uniqueCompetitionRows(competitionId)
        : cachedForCompetition(competitionId, seasonId: seasonId) ?? const [];
    return List.unmodifiable(rows);
  }

  List<XgStanding> _uniqueCompetitionRows(int competitionId) {
    final unique = <(int, int), XgStanding>{};
    for (final entry in _cachedTables.value.entries) {
      if (entry.key.competitionId != competitionId) continue;
      for (final standing in entry.value) {
        unique[(standing.seasonId, standing.teamId)] = standing;
      }
    }
    return unique.values.toList(growable: false);
  }

  @override
  XgStanding? findForTeam(
    int competitionId,
    int teamId, {
    int? seasonId,
  }) {
    for (final standing in forCompetition(
      competitionId,
      seasonId: seasonId,
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
