import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  group('fixtureFromApiResponse', () {
    test('maps supported competition and status values explicitly', () {
      const cases = [
        ('league', CompetitionType.league, 'past', FixtureStatus.past),
        ('europe', CompetitionType.europe, 'live', FixtureStatus.live),
        (
          'domestic_cup',
          CompetitionType.cup,
          'upcoming',
          FixtureStatus.upcoming,
        ),
      ];

      for (final testCase in cases) {
        final fixture = fixtureFromApiResponse(
          _response(
            competitionType: testCase.$1,
            status: testCase.$3,
          ),
        );

        expect(fixture.competitionType, testCase.$2);
        expect(fixture.status, testCase.$4);
      }
    });

    test('copies the domain fields used by the application', () {
      final fixture = fixtureFromApiResponse(_response());

      expect(fixture.fixtureId, 19712345);
      expect(fixture.seasonId, 25583);
      expect(fixture.competitionId, 8);
      expect(fixture.homeTeamId, 8);
      expect(fixture.awayTeamId, 19);
      expect(fixture.roundName, '3');
      expect(fixture.stageId, 77432101);
      expect(fixture.groupId, 42);
      expect(fixture.startingAt, '2026-08-29T14:00:00.000Z');
      expect(fixture.kickoff, DateTime.utc(2026, 8, 29, 14));
      expect(fixture.homeScore, 2);
      expect(fixture.awayScore, 1);
      expect(fixture.homePenaltyScore, 5);
      expect(fixture.awayPenaltyScore, 4);
    });

    test('preserves nullable domain values', () {
      final fixture = fixtureFromApiResponse(
        _response(
          roundName: null,
          groupId: null,
          status: null,
          startingAt: null,
          homeScore: null,
          awayScore: null,
          homePenaltyScore: null,
          awayPenaltyScore: null,
        ),
      );

      expect(fixture.roundName, isNull);
      expect(fixture.groupId, isNull);
      expect(fixture.status, FixtureStatus.unknown);
      expect(fixture.startingAt, isNull);
      expect(fixture.kickoff, isNull);
      expect(fixture.homeScore, isNull);
      expect(fixture.awayScore, isNull);
      expect(fixture.homePenaltyScore, isNull);
      expect(fixture.awayPenaltyScore, isNull);
    });

    test('maps an unrecognized optional status to unknown', () {
      final fixture = fixtureFromApiResponse(
        _response(status: 'postponed'),
      );

      expect(fixture.status, FixtureStatus.unknown);
    });

    test('preserves the instant from an offset-aware timestamp', () {
      final fixture = fixtureFromApiResponse(
        _response(startingAt: '2026-08-29T15:00:00+01:00'),
      );

      expect(fixture.startingAt, '2026-08-29T14:00:00.000Z');
      expect(fixture.kickoff, DateTime.utc(2026, 8, 29, 14));
    });

    test('rejects an unsupported required competition type', () {
      expect(
        () => fixtureFromApiResponse(
          _response(competitionType: 'international'),
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('international'),
          ),
        ),
      );
    });
  });
}

ApiFixtureResponse _response({
  String competitionType = 'league',
  String? roundName = '3',
  int? groupId = 42,
  String? status = 'upcoming',
  String? startingAt = '2026-08-29 14:00:00',
  int? homeScore = 2,
  int? awayScore = 1,
  int? homePenaltyScore = 5,
  int? awayPenaltyScore = 4,
}) {
  return ApiFixtureResponse(
    fixtureId: 19712345,
    competitionId: 8,
    seasonId: 25583,
    competitionType: competitionType,
    roundName: roundName,
    stageId: 77432101,
    stageName: 'Regular Season',
    roundId: 375001,
    groupId: groupId,
    aggregateId: null,
    leg: '1/1',
    venueId: 206,
    stateId: 1,
    stateCode: 'NS',
    stateName: 'Not Started',
    status: status,
    startingAt: startingAt,
    homeTeamId: 8,
    awayTeamId: 19,
    homeScore: homeScore,
    awayScore: awayScore,
    homePenaltyScore: homePenaltyScore,
    awayPenaltyScore: awayPenaltyScore,
    homeTeamName: 'Liverpool',
    awayTeamName: 'Arsenal',
    homeTeamLogo: 'https://cdn.example/liverpool.png',
    awayTeamLogo: null,
  );
}
