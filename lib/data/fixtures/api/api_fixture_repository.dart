import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/models/fixture.dart';

/// HTTP implementation of the verified team-matches fixture query.
///
/// The synchronous selectors expose only fixtures loaded during this process;
/// they are not a complete backend catalog. Keep the active provider on the
/// mock until existing screens migrate to asynchronous repository operations.
class ApiFixtureRepository implements FixtureRepository {
  ApiFixtureRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<List<Fixture>> _fixtures = ValueNotifier(const []);

  @override
  List<Fixture> get allFixtures => _fixtures.value;

  @override
  ValueListenable<List<Fixture>> get fixtures => _fixtures;

  @override
  Fixture? findById(int fixtureId) => _fixtures.value
      .where((fixture) => fixture.fixtureId == fixtureId)
      .firstOrNull;

  @override
  List<Fixture> forTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
    FixtureStatus? status,
  }) {
    return List.unmodifiable(
      _fixtures.value.where(
        (fixture) =>
            (fixture.homeTeamId == teamId || fixture.awayTeamId == teamId) &&
            _matchesFilters(
              fixture,
              seasonId: seasonId,
              competitionId: competitionId,
              status: status,
            ),
      ),
    );
  }

  @override
  Future<List<Fixture>> loadForTeam(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  }) async {
    if (status == FixtureStatus.unknown) {
      throw ArgumentError.value(
        status,
        'status',
        'must be past, live, upcoming, or null',
      );
    }
    if (limit < 1 || limit > 200) {
      throw RangeError.range(limit, 1, 200, 'limit');
    }
    if (offset < 0) {
      throw RangeError.range(offset, 0, null, 'offset');
    }

    final queryParameters = <String, String>{
      if (status != null) 'status': status.name,
      if (start != null) 'start': _formatDate(start),
      if (end != null) 'end': _formatDate(end),
      'limit': '$limit',
      'offset': '$offset',
    };
    final uri = _apiBaseUri.resolve('teams/$teamId/matches').replace(
          queryParameters: queryParameters,
        );
    final decoded = await _getJsonObject(uri, 'team-matches');
    final page = ApiTeamMatchesResponse.fromJson(decoded);
    final loaded = List<Fixture>.unmodifiable(
      page.items.map(fixtureFromApiResponse),
    );
    _mergeIntoCache(loaded);
    return loaded;
  }

  @override
  List<Fixture> forCompetition(
    int competitionId, {
    int? seasonId,
    FixtureStatus? status,
    CompetitionType? competitionType,
  }) {
    return List.unmodifiable(
      _fixtures.value.where(
        (fixture) =>
            fixture.competitionId == competitionId &&
            _matchesFilters(
              fixture,
              seasonId: seasonId,
              status: status,
              competitionType: competitionType,
            ),
      ),
    );
  }

  @override
  Fixture? nextForTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
  }) {
    return forTeam(
      teamId,
      seasonId: seasonId,
      competitionId: competitionId,
      status: FixtureStatus.upcoming,
    ).where((fixture) => fixture.kickoff != null).firstOrNull;
  }

  @override
  Fixture? lastForTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
  }) {
    return forTeam(
      teamId,
      seasonId: seasonId,
      competitionId: competitionId,
      status: FixtureStatus.past,
    ).where((fixture) => fixture.kickoff != null).lastOrNull;
  }

  @override
  List<Fixture> headToHead(
    int firstTeamId,
    int secondTeamId, {
    int? seasonId,
    int? competitionId,
  }) {
    final matches = forTeam(
      firstTeamId,
      seasonId: seasonId,
      competitionId: competitionId,
      status: FixtureStatus.past,
    )
        .where(
          (fixture) =>
              fixture.homeTeamId == secondTeamId ||
              fixture.awayTeamId == secondTeamId,
        )
        .toList()
      ..sort((a, b) => _compareChronologically(a, b, descending: true));
    return List.unmodifiable(matches);
  }

  @override
  Future<List<Fixture>> loadHeadToHead(
    int fixtureId, {
    int limit = 10,
  }) async {
    if (limit < 1 || limit > 50) {
      throw RangeError.range(limit, 1, 50, 'limit');
    }

    final uri = _apiBaseUri.resolve('fixtures/$fixtureId/head2head').replace(
      queryParameters: {'limit': '$limit'},
    );
    final decoded = await _getJsonObject(uri, 'head-to-head');
    final response = ApiFixtureHeadToHeadResponse.fromJson(decoded);
    if (response.fixtureId != fixtureId) {
      throw FormatException(
        'Expected fixture_id $fixtureId but received ${response.fixtureId}.',
      );
    }

    final loaded = List<Fixture>.unmodifiable(
      response.items.map(fixtureFromApiResponse),
    );
    _mergeIntoCache(loaded);
    return loaded;
  }

  @override
  Future<void> initialize() async {}

  Future<Map<String, dynamic>> _getJsonObject(
    Uri uri,
    String responseName,
  ) async {
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Fixture request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
          'Expected the $responseName response to be a JSON object.');
    }
    return decoded;
  }

  void _mergeIntoCache(List<Fixture> loaded) {
    final byId = {
      for (final fixture in _fixtures.value) fixture.fixtureId: fixture,
      for (final fixture in loaded) fixture.fixtureId: fixture,
    };
    final merged = byId.values.toList()..sort(_compareChronologically);
    _fixtures.value = List.unmodifiable(merged);
  }

  static bool _matchesFilters(
    Fixture fixture, {
    int? seasonId,
    int? competitionId,
    FixtureStatus? status,
    CompetitionType? competitionType,
  }) {
    return (seasonId == null || fixture.seasonId == seasonId) &&
        (competitionId == null || fixture.competitionId == competitionId) &&
        (status == null || fixture.status == status) &&
        (competitionType == null || fixture.competitionType == competitionType);
  }

  static int _compareChronologically(
    Fixture a,
    Fixture b, {
    bool descending = false,
  }) {
    final aKickoff = a.kickoff;
    final bKickoff = b.kickoff;
    if (aKickoff == null || bKickoff == null) {
      if (aKickoff == null && bKickoff == null) {
        return a.fixtureId.compareTo(b.fixtureId);
      }
      return aKickoff == null ? 1 : -1;
    }

    final dateComparison = descending
        ? bKickoff.compareTo(aKickoff)
        : aKickoff.compareTo(bKickoff);
    if (dateComparison != 0) return dateComparison;
    return descending
        ? b.fixtureId.compareTo(a.fixtureId)
        : a.fixtureId.compareTo(b.fixtureId);
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
