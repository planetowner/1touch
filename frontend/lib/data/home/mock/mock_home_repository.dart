import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/models/home_data.dart';

class MockHomeRepository implements HomeRepository {
  MockHomeRepository({
    required TeamRepository teamRepository,
    required FixtureRepository fixtureRepository,
    required int Function() favoriteTeamId,
    required List<int> Function() followedTeamIds,
  })  : _teamRepository = teamRepository,
        _fixtureRepository = fixtureRepository,
        _favoriteTeamId = favoriteTeamId,
        _followedTeamIds = followedTeamIds;

  final TeamRepository _teamRepository;
  final FixtureRepository _fixtureRepository;
  final int Function() _favoriteTeamId;
  final List<int> Function() _followedTeamIds;

  @override
  Future<HomeData> load({DateTime? start, DateTime? end}) async {
    final followingTeams = [
      for (final teamId in _followedTeamIds())
        if (_teamRepository.findById(teamId) case final team?) team,
    ];
    final favoriteTeamId = _favoriteTeamId();
    final favoriteTeam = _teamRepository.findById(favoriteTeamId);
    if (favoriteTeam == null ||
        !followingTeams.any((team) => team.teamId == favoriteTeamId)) {
      throw StateError(
        'Favorite team $favoriteTeamId must exist in the followed-team list.',
      );
    }

    return HomeData(
      favoriteTeam: favoriteTeam,
      followingTeams: followingTeams,
      nextMatch: _fixtureRepository.nextForTeam(favoriteTeam.teamId),
      lastMatch: _fixtureRepository.lastForTeam(favoriteTeam.teamId),
      calendar: _calendarForTeam(
        favoriteTeam.teamId,
        start: start,
        end: end,
      ),
    );
  }

  List<HomeCalendarFixture> _calendarForTeam(
    int teamId, {
    required DateTime? start,
    required DateTime? end,
  }) {
    if (start == null && end == null) return const [];

    final startDate = start == null ? null : _dateOnly(start);
    final exclusiveEnd =
        end == null ? null : _dateOnly(end).add(const Duration(days: 1));
    final fixtures = _fixtureRepository.forTeam(teamId).where((fixture) {
      final kickoff = fixture.kickoff;
      if (kickoff == null) return false;
      return (startDate == null || !kickoff.isBefore(startDate)) &&
          (exclusiveEnd == null || kickoff.isBefore(exclusiveEnd));
    }).toList()
      ..sort((left, right) => right.kickoff!.compareTo(left.kickoff!));

    return List.unmodifiable(
      fixtures.take(200).map((fixture) {
        final opponentTeamId = fixture.homeTeamId == teamId
            ? fixture.awayTeamId
            : fixture.homeTeamId;
        return HomeCalendarFixture(
          fixture: fixture,
          opponent: _teamRepository.findByIdOrUnknown(opponentTeamId),
        );
      }),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
