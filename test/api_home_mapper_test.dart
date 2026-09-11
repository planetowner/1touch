import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/home/api/api_home_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  group('homeDataFromApiResponse', () {
    test('maps teams, fixtures, and derived live match', () {
      final home = homeDataFromApiResponse(
        _response(
          nextMatch: _fixture(1001, FixtureStatus.upcoming),
          lastMatch: _fixture(1002, FixtureStatus.past),
          calendar: [_fixture(1003, FixtureStatus.live)],
        ),
      );

      expect(home.favoriteTeam.teamId, 8);
      expect(home.favoriteTeam.name, 'Liverpool');
      expect(home.followingTeams.map((team) => team.teamId), [8, 19]);
      expect(home.nextMatch?.fixtureId, 1001);
      expect(home.lastMatch?.fixtureId, 1002);
      expect(home.calendar.single.fixtureId, 1003);
      expect(home.liveMatch?.fixtureId, 1003);
    });

    test('preserves absent next and last matches without inventing values', () {
      final home = homeDataFromApiResponse(_response());

      expect(home.nextMatch, isNull);
      expect(home.lastMatch, isNull);
      expect(home.calendar, isEmpty);
      expect(home.liveMatch, isNull);
    });

    test('rejects a missing favorite team', () {
      expect(
        () => homeDataFromApiResponse(
          _response(includeFavoriteTeam: false),
        ),
        throwsStateError,
      );
    });

    test('rejects a favorite team outside the followed-team list', () {
      expect(
        () => homeDataFromApiResponse(
          _response(
            favoriteTeam: _team(20, 'Chelsea', 'CHE'),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('20'),
          ),
        ),
      );
    });

    test('returns immutable domain collections', () {
      final home = homeDataFromApiResponse(
        _response(calendar: [_fixture(1003, FixtureStatus.live)]),
      );

      expect(() => home.followingTeams.clear(), throwsUnsupportedError);
      expect(() => home.calendar.clear(), throwsUnsupportedError);
    });
  });
}

ApiHomeResponse _response({
  ApiTeamResponse favoriteTeam = const ApiTeamResponse(
    teamId: 8,
    name: 'Liverpool',
    shortCode: 'LIV',
    imagePath: 'https://cdn.example/8.png',
  ),
  bool includeFavoriteTeam = true,
  ApiFixtureResponse? nextMatch,
  ApiFixtureResponse? lastMatch,
  List<ApiFixtureResponse> calendar = const [],
}) {
  return ApiHomeResponse(
    favoriteTeam: includeFavoriteTeam ? favoriteTeam : null,
    followingTeams: const [
      ApiTeamResponse(
        teamId: 8,
        name: 'Liverpool',
        shortCode: 'LIV',
        imagePath: 'https://cdn.example/8.png',
      ),
      ApiTeamResponse(
        teamId: 19,
        name: 'Arsenal',
        shortCode: 'ARS',
        imagePath: 'https://cdn.example/19.png',
      ),
    ],
    nextMatch: nextMatch,
    lastMatch: lastMatch,
    calendar: calendar,
  );
}

ApiTeamResponse _team(int id, String name, String shortCode) {
  return ApiTeamResponse(
    teamId: id,
    name: name,
    shortCode: shortCode,
    imagePath: 'https://cdn.example/$id.png',
  );
}

ApiFixtureResponse _fixture(int fixtureId, FixtureStatus status) {
  return ApiFixtureResponse(
    fixtureId: fixtureId,
    competitionId: 8,
    seasonId: 25583,
    competitionType: 'league',
    roundName: '3',
    stageId: 77432101,
    stageName: 'Regular Season',
    roundId: 375001,
    groupId: null,
    aggregateId: null,
    leg: '1/1',
    venueId: 206,
    stateId: 1,
    stateCode: 'NS',
    stateName: 'Not Started',
    status: status.name,
    startingAt: '2026-08-29 14:00:00',
    homeTeamId: 8,
    awayTeamId: 19,
    homeScore: status == FixtureStatus.past ? 2 : null,
    awayScore: status == FixtureStatus.past ? 1 : null,
    homePenaltyScore: null,
    awayPenaltyScore: null,
    homeTeamName: 'Liverpool',
    awayTeamName: 'Arsenal',
    homeTeamLogo: 'https://cdn.example/8.png',
    awayTeamLogo: 'https://cdn.example/19.png',
  );
}
