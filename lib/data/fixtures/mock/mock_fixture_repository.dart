import 'package:flutter/foundation.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/models/fixture.dart';

class MockFixtureRepository implements FixtureRepository {
  MockFixtureRepository({List<Fixture>? fixtures}) {
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
    _fixtures = ValueNotifier(_allFixtures);
  }

  late final List<Fixture> _allFixtures;
  late final Map<int, Fixture> _fixturesById;
  late final Map<int, List<Fixture>> _fixturesByTeam;
  late final ValueNotifier<List<Fixture>> _fixtures;

  @override
  List<Fixture> get allFixtures => _allFixtures;

  @override
  ValueListenable<List<Fixture>> get fixtures => _fixtures;

  @override
  Fixture? findById(int fixtureId) => _fixturesById[fixtureId];

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
    ).firstOrNull;
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
    ).lastOrNull;
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
      ..sort((a, b) => _compareChronologically(b, a));
    return List.unmodifiable(matches);
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

  static int _compareChronologically(Fixture a, Fixture b) {
    final dateComparison =
        DateTime.parse(a.startingAt).compareTo(DateTime.parse(b.startingAt));
    if (dateComparison != 0) return dateComparison;
    return a.fixtureId.compareTo(b.fixtureId);
  }
}
