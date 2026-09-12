import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';

void main() {
  group('ApiFixtureResponse', () {
    test('parses the current backend FixtureOut shape', () {
      final fixture = ApiFixtureResponse.fromJson(_fixtureJson());

      expect(fixture.fixtureId, 19712345);
      expect(fixture.competitionId, 8);
      expect(fixture.seasonId, 25583);
      expect(fixture.competitionType, 'league');
      expect(fixture.roundName, '3');
      expect(fixture.stageId, 77432101);
      expect(fixture.stageName, 'Regular Season');
      expect(fixture.roundId, 375001);
      expect(fixture.groupId, isNull);
      expect(fixture.aggregateId, isNull);
      expect(fixture.leg, '1/1');
      expect(fixture.venueId, 206);
      expect(fixture.stateId, 1);
      expect(fixture.stateCode, 'NS');
      expect(fixture.stateName, 'Not Started');
      expect(fixture.status, 'upcoming');
      expect(fixture.startingAt, '2026-08-29 14:00:00');
      expect(fixture.homeTeamId, 8);
      expect(fixture.awayTeamId, 19);
      expect(fixture.homeTeamName, 'Liverpool');
      expect(fixture.awayTeamName, 'Arsenal');
      expect(fixture.homeTeamLogo, 'https://cdn.example/liverpool.png');
      expect(fixture.awayTeamLogo, isNull);
    });

    test('preserves fields that are legitimately nullable', () {
      final fixture = ApiFixtureResponse.fromJson(_fixtureJson(
        roundName: null,
        roundId: null,
        groupId: null,
        aggregateId: null,
        venueId: null,
        status: null,
        startingAt: null,
        homeScore: null,
        awayScore: null,
        homePenaltyScore: null,
        awayPenaltyScore: null,
        homeTeamLogo: null,
        awayTeamLogo: null,
      ));

      expect(fixture.roundName, isNull);
      expect(fixture.roundId, isNull);
      expect(fixture.groupId, isNull);
      expect(fixture.aggregateId, isNull);
      expect(fixture.venueId, isNull);
      expect(fixture.status, isNull);
      expect(fixture.startingAt, isNull);
      expect(fixture.homeScore, isNull);
      expect(fixture.awayScore, isNull);
      expect(fixture.homePenaltyScore, isNull);
      expect(fixture.awayPenaltyScore, isNull);
      expect(fixture.homeTeamLogo, isNull);
      expect(fixture.awayTeamLogo, isNull);
    });

    test('rejects a missing required team name', () {
      final json = _fixtureJson()..remove('home_team_name');

      expect(
        () => ApiFixtureResponse.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('home_team_name'),
          ),
        ),
      );
    });

    test('rejects a null required team name', () {
      expect(
        () => ApiFixtureResponse.fromJson(_fixtureJson(awayTeamName: null)),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('away_team_name'),
          ),
        ),
      );
    });

    test('rejects a field with the wrong transport type', () {
      final json = _fixtureJson()..['leg'] = 1;

      expect(
        () => ApiFixtureResponse.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('leg'),
          ),
        ),
      );
    });
  });

  group('ApiTeamMatchesResponse', () {
    test('parses the verified paginated team-matches envelope', () {
      final response = ApiTeamMatchesResponse.fromJson({
        'items': [_fixtureJson(), _fixtureJson()],
        'limit': 50,
        'offset': 20,
      });

      expect(response.items, hasLength(2));
      expect(response.items.first.fixtureId, 19712345);
      expect(response.limit, 50);
      expect(response.offset, 20);
      expect(() => response.items.clear(), throwsUnsupportedError);
    });

    test('rejects malformed item collections and entries', () {
      expect(
        () => ApiTeamMatchesResponse.fromJson({
          'items': 'not-a-list',
          'limit': 50,
          'offset': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => ApiTeamMatchesResponse.fromJson({
          'items': ['not-an-object'],
          'limit': 50,
          'offset': 0,
        }),
        throwsFormatException,
      );
    });

    test('rejects pagination metadata outside backend constraints', () {
      for (final pagination in [
        (limit: 0, offset: 0),
        (limit: 201, offset: 0),
        (limit: 50, offset: -1),
      ]) {
        expect(
          () => ApiTeamMatchesResponse.fromJson({
            'items': const [],
            'limit': pagination.limit,
            'offset': pagination.offset,
          }),
          throwsFormatException,
        );
      }
    });
  });

  group('ApiFixtureHeadToHeadResponse', () {
    test('parses the verified head-to-head response', () {
      final response = ApiFixtureHeadToHeadResponse.fromJson({
        'fixture_id': 1001,
        'team_a': 8,
        'team_b': 14,
        'items': [_fixtureJson()],
      });

      expect(response.fixtureId, 1001);
      expect(response.teamA, 8);
      expect(response.teamB, 14);
      expect(response.items.single.fixtureId, 19712345);
      expect(() => response.items.clear(), throwsUnsupportedError);
    });

    test('rejects malformed identity fields', () {
      for (final field in ['fixture_id', 'team_a', 'team_b']) {
        final json = <String, dynamic>{
          'fixture_id': 1001,
          'team_a': 8,
          'team_b': 14,
          'items': const [],
        }..[field] = null;

        expect(
          () => ApiFixtureHeadToHeadResponse.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(field),
            ),
          ),
        );
      }
    });

    test('rejects malformed item collections and entries', () {
      expect(
        () => ApiFixtureHeadToHeadResponse.fromJson({
          'fixture_id': 1001,
          'team_a': 8,
          'team_b': 14,
          'items': 'not-a-list',
        }),
        throwsFormatException,
      );
      expect(
        () => ApiFixtureHeadToHeadResponse.fromJson({
          'fixture_id': 1001,
          'team_a': 8,
          'team_b': 14,
          'items': ['not-an-object'],
        }),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _fixtureJson({
  String? roundName = '3',
  int? roundId = 375001,
  int? groupId,
  int? aggregateId,
  int? venueId = 206,
  String? status = 'upcoming',
  String? startingAt = '2026-08-29 14:00:00',
  int? homeScore,
  int? awayScore,
  int? homePenaltyScore,
  int? awayPenaltyScore,
  Object? homeTeamName = 'Liverpool',
  Object? awayTeamName = 'Arsenal',
  String? homeTeamLogo = 'https://cdn.example/liverpool.png',
  String? awayTeamLogo,
}) {
  return <String, dynamic>{
    'fixture_id': 19712345,
    'competition_id': 8,
    'season_id': 25583,
    'competition_type': 'league',
    'round_name': roundName,
    'stage_id': 77432101,
    'stage_name': 'Regular Season',
    'round_id': roundId,
    'group_id': groupId,
    'aggregate_id': aggregateId,
    'leg': '1/1',
    'venue_id': venueId,
    'state_id': 1,
    'state_code': 'NS',
    'state_name': 'Not Started',
    'status': status,
    'starting_at': startingAt,
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': homeScore,
    'away_score': awayScore,
    'home_penalty_score': homePenaltyScore,
    'away_penalty_score': awayPenaltyScore,
    'home_team_name': homeTeamName,
    'away_team_name': awayTeamName,
    'home_team_logo': homeTeamLogo,
    'away_team_logo': awayTeamLogo,
  };
}
