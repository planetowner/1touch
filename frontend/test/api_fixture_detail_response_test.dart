import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_detail_response.dart';

void main() {
  group('ApiFixtureDetailResponse', () {
    test('parses the verified fixture-detail response', () {
      final response = ApiFixtureDetailResponse.fromJson(_detailJson());

      expect(response.fixture.fixtureId, 500);
      expect(response.venueName, 'Emirates Stadium');
      expect(response.expectedGoals?.homeXg, 1.75);
      expect(response.expectedGoals?.awayXga, 1.75);
      expect(response.expectedGoals?.provider, 'understat');

      expect(response.playerExpectedGoals.single.playerName, 'Home Player');
      expect(response.playerExpectedGoals.single.xg, 0.6);

      final shot = response.shots.single;
      expect(shot.shotId, 8100);
      expect(shot.x, 0.88);
      expect(shot.result, 'Goal');

      final event = response.events.single;
      expect(event.eventTypeCode, 'goal');
      expect(event.relatedPlayerId, 202);
      expect(event.extraMinute, 2);
      expect(event.onBench, isFalse);

      final statistic = response.statistics.single;
      expect(statistic.statCode, 'ball-possession');
      expect(statistic.value, 63);

      final lineup = response.lineups.single;
      expect(lineup.playerName, 'Home Player');
      expect(lineup.positionId, 24);
      expect(lineup.rating, 7.45);

      expect(response.formations.single.formation, '4-3-3');
      expect(response.coaches.single.name, 'Coach Name');
      expect(response.pressure.single.pressure, 12.5);

      expect(() => response.events.clear(), throwsUnsupportedError);
      expect(() => response.pressure.clear(), throwsUnsupportedError);
    });

    test('preserves unavailable detail data without inventing values', () {
      final response = ApiFixtureDetailResponse.fromJson(
        _detailJson(
          venueName: null,
          expectedGoals: null,
          playerExpectedGoals: const [],
          shots: const [],
          events: const [],
          statistics: const [],
          lineups: const [],
          formations: const [],
          coaches: const [],
          pressure: const [],
        ),
      );

      expect(response.venueName, isNull);
      expect(response.expectedGoals, isNull);
      expect(response.playerExpectedGoals, isEmpty);
      expect(response.shots, isEmpty);
      expect(response.events, isEmpty);
      expect(response.statistics, isEmpty);
      expect(response.lineups, isEmpty);
      expect(response.formations, isEmpty);
      expect(response.coaches, isEmpty);
      expect(response.pressure, isEmpty);
    });

    test('accepts nullable event and lineup fields from the database', () {
      final json = _detailJson();
      json['events'] = [
        {
          'event_id': 900,
          'team_id': 8,
          'event_type_id': 19,
          'event_type_code': 'yellowcard',
          'event_type_name': 'Yellow Card',
          'player_id': null,
          'player_name': null,
          'player_image': null,
          'related_player_id': null,
          'related_player_name': null,
          'related_player_image': null,
          'minute': 44,
          'extra_minute': null,
          'on_bench': null,
        },
      ];
      json['lineups'] = [
        {
          'team_id': 8,
          'player_id': 101,
          'player_name': 'Home Player',
          'player_image': null,
          'position_id': null,
          'lineup_type_id': 1,
          'formation_field': null,
          'jersey_number': null,
          'minutes_played': null,
          'rating': null,
        },
      ];

      final response = ApiFixtureDetailResponse.fromJson(json);

      expect(response.events.single.playerId, isNull);
      expect(response.events.single.relatedPlayerId, isNull);
      expect(response.events.single.onBench, isNull);
      expect(response.lineups.single.positionId, isNull);
      expect(response.lineups.single.minutesPlayed, isNull);
      expect(response.lineups.single.rating, isNull);
    });

    test('accepts boolean and database integer forms of on_bench', () {
      final booleanJson = _detailJson();
      (booleanJson['events'] as List).single['on_bench'] = true;
      final integerJson = _detailJson();
      (integerJson['events'] as List).single['on_bench'] = 1;

      expect(
        ApiFixtureDetailResponse.fromJson(booleanJson).events.single.onBench,
        isTrue,
      );
      expect(
        ApiFixtureDetailResponse.fromJson(integerJson).events.single.onBench,
        isTrue,
      );
    });

    test('rejects a missing required detail collection', () {
      final json = _detailJson()..remove('pressure');

      expect(
        () => ApiFixtureDetailResponse.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('pressure'),
          ),
        ),
      );
    });

    test('rejects malformed nested entries and required values', () {
      final malformedEntry = _detailJson()..['shots'] = ['not-an-object'];
      final malformedValue = _detailJson();
      (malformedValue['statistics'] as List).single['value'] = '63';

      expect(
        () => ApiFixtureDetailResponse.fromJson(malformedEntry),
        throwsFormatException,
      );
      expect(
        () => ApiFixtureDetailResponse.fromJson(malformedValue),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('value'),
          ),
        ),
      );
    });

    test('requires expected_goals to be present as an object or null', () {
      final missing = _detailJson()..remove('expected_goals');
      final malformed = _detailJson()..['expected_goals'] = [];

      expect(
        () => ApiFixtureDetailResponse.fromJson(missing),
        throwsFormatException,
      );
      expect(
        () => ApiFixtureDetailResponse.fromJson(malformed),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _detailJson({
  String? venueName = 'Emirates Stadium',
  Object? expectedGoals = const {
    'home_xg': 1.75,
    'away_xg': 0.9,
    'home_xga': 0.9,
    'away_xga': 1.75,
    'provider': 'understat',
  },
  List<Object?> playerExpectedGoals = const [
    {'player_id': 101, 'player_name': 'Home Player', 'xg': 0.6},
  ],
  List<Object?> shots = const [
    {
      'shot_id': 8100,
      'team_id': 8,
      'player_id': 101,
      'player_name': 'Home Player',
      'minute': 32,
      'x': 0.88,
      'y': 0.51,
      'xg': 0.6,
      'result': 'Goal',
    },
  ],
  List<Object?> events = const [
    {
      'event_id': 900,
      'team_id': 8,
      'event_type_id': 14,
      'event_type_code': 'goal',
      'event_type_name': 'Goal',
      'player_id': 101,
      'player_name': 'Home Player',
      'player_image': 'https://cdn.example/home-player.png',
      'related_player_id': 202,
      'related_player_name': 'Assisting Player',
      'related_player_image': null,
      'minute': 45,
      'extra_minute': 2,
      'on_bench': 0,
    },
  ],
  List<Object?> statistics = const [
    {
      'team_id': 8,
      'stat_type_id': 45,
      'stat_code': 'ball-possession',
      'stat_name': 'Ball Possession',
      'value': 63,
    },
  ],
  List<Object?> lineups = const [
    {
      'team_id': 8,
      'player_id': 101,
      'player_name': 'Home Player',
      'player_image': 'https://cdn.example/home-player.png',
      'position_id': 24,
      'lineup_type_id': 1,
      'formation_field': '1:4',
      'jersey_number': 9,
      'minutes_played': 90,
      'rating': 7.45,
    },
  ],
  List<Object?> formations = const [
    {'team_id': 8, 'formation': '4-3-3'},
  ],
  List<Object?> coaches = const [
    {'team_id': 8, 'coach_id': 700, 'name': 'Coach Name'},
  ],
  List<Object?> pressure = const [
    {'team_id': 8, 'minute': 1, 'pressure': 12.5},
  ],
}) {
  return <String, dynamic>{
    'fixture_id': 500,
    'competition_id': 8,
    'season_id': 25583,
    'competition_type': 'league',
    'round_name': '3',
    'stage_id': 77432101,
    'stage_name': 'Regular Season',
    'round_id': 375001,
    'group_id': null,
    'aggregate_id': null,
    'leg': '1/1',
    'venue_id': 206,
    'venue_name': venueName,
    'state_id': 5,
    'state_code': 'FT',
    'state_name': 'Finished',
    'status': 'past',
    'starting_at': '2026-08-29 14:00:00',
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': 2,
    'away_score': 1,
    'home_penalty_score': null,
    'away_penalty_score': null,
    'home_team_name': 'Liverpool',
    'away_team_name': 'Arsenal',
    'home_team_logo': 'https://cdn.example/liverpool.png',
    'away_team_logo': 'https://cdn.example/arsenal.png',
    'expected_goals': expectedGoals is Map
        ? Map<String, dynamic>.from(expectedGoals)
        : expectedGoals,
    'player_expected_goals': _copyEntries(playerExpectedGoals),
    'shots': _copyEntries(shots),
    'events': _copyEntries(events),
    'statistics': _copyEntries(statistics),
    'lineups': _copyEntries(lineups),
    'formations': _copyEntries(formations),
    'coaches': _copyEntries(coaches),
    'pressure': _copyEntries(pressure),
  };
}

List<Object?> _copyEntries(List<Object?> entries) {
  return entries
      .map(
        (entry) => entry is Map ? Map<String, dynamic>.from(entry) : entry,
      )
      .toList();
}
