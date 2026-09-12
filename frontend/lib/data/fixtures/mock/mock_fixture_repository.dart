import 'package:flutter/foundation.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';

class MockFixtureRepository implements FixtureRepository {
  MockFixtureRepository({
    List<Fixture>? fixtures,
    List<FixtureDetail>? fixtureDetails,
  }) {
    final sortedFixtures = List<Fixture>.of(fixtures ?? mockFixtures)
      ..sort(_compareChronologically);
    _allFixtures = List.unmodifiable(sortedFixtures);
    _fixturesById = Map.unmodifiable({
      for (final fixture in _allFixtures) fixture.fixtureId: fixture,
    });

    final byTeam = <int, List<Fixture>>{};
    for (final fixture in _allFixtures) {
      byTeam.putIfAbsent(fixture.homeTeamId, () => []).add(fixture);
      byTeam.putIfAbsent(fixture.awayTeamId, () => []).add(fixture);
    }
    _fixturesByTeam = Map.unmodifiable({
      for (final entry in byTeam.entries)
        entry.key: List<Fixture>.unmodifiable(entry.value),
    });
    _fixtureDetailsById = Map.unmodifiable({
      for (final detail in fixtureDetails ?? const <FixtureDetail>[])
        detail.fixture.fixtureId: detail,
    });
    _fixtures = ValueNotifier(_allFixtures);
  }

  late final List<Fixture> _allFixtures;
  late final Map<int, Fixture> _fixturesById;
  late final Map<int, List<Fixture>> _fixturesByTeam;
  late final Map<int, FixtureDetail> _fixtureDetailsById;
  late final ValueNotifier<List<Fixture>> _fixtures;

  @override
  List<Fixture> get allFixtures => _allFixtures;

  @override
  ValueListenable<List<Fixture>> get fixtures => _fixtures;

  @override
  Fixture? findById(int fixtureId) => _fixturesById[fixtureId];

  @override
  Future<FixtureDetail> loadDetail(int fixtureId) async {
    final detail = _fixtureDetailsById[fixtureId];
    if (detail == null) {
      throw StateError('Fixture detail $fixtureId was not found.');
    }
    return detail;
  }

  @override
  List<Fixture> forTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
    FixtureStatus? status,
  }) {
    final teamFixtures = _fixturesByTeam[teamId] ?? const <Fixture>[];
    return List.unmodifiable(
      teamFixtures.where(
        (fixture) => _matchesFilters(
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

    final startDate = start == null ? null : _dateOnly(start);
    final endDate = end == null ? null : _dateOnly(end);
    final matches = forTeam(teamId, status: status).where((fixture) {
      final kickoff = fixture.kickoff;
      if (kickoff == null) return startDate == null && endDate == null;

      final kickoffDate = _dateOnly(kickoff);
      return (startDate == null || !kickoffDate.isBefore(startDate)) &&
          (endDate == null || !kickoffDate.isAfter(endDate));
    }).toList()
      ..sort((a, b) => _compareChronologically(a, b, descending: true));

    return List.unmodifiable(matches.skip(offset).take(limit));
  }

  @override
  List<Fixture> forCompetition(
    int competitionId, {
    int? seasonId,
    FixtureStatus? status,
    CompetitionType? competitionType,
  }) {
    return List.unmodifiable(
      _allFixtures.where(
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

    final fixture = findById(fixtureId);
    if (fixture == null) {
      throw StateError('Fixture $fixtureId was not found.');
    }
    return List.unmodifiable(
      headToHead(fixture.homeTeamId, fixture.awayTeamId).take(limit),
    );
  }

  @override
  Future<void> initialize() async {}

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

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
