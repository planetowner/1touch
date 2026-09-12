import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';

void main() {
  group('ApiHomeResponse', () {
    test('parses the verified HomeResponse shape', () {
      final response = ApiHomeResponse.fromJson(_homeJson());

      expect(response.favoriteTeam?.teamId, 8);
      expect(
        response.followingTeams.map((team) => team.teamId),
        [8, 19],
      );
      expect(response.nextMatch?.fixtureId, 1001);
      expect(response.lastMatch?.fixtureId, 1002);
      expect(response.calendar.single.fixtureId, 1003);
      expect(() => response.followingTeams.clear(), throwsUnsupportedError);
      expect(() => response.calendar.clear(), throwsUnsupportedError);
    });

    test('preserves nullable teams and fixtures with empty collections', () {
      final response = ApiHomeResponse.fromJson({
        'favorite_team': null,
        'following_teams': [],
        'next_match': null,
        'last_match': null,
        'calendar': [],
      });

      expect(response.favoriteTeam, isNull);
      expect(response.followingTeams, isEmpty);
      expect(response.nextMatch, isNull);
      expect(response.lastMatch, isNull);
      expect(response.calendar, isEmpty);
    });

    test('rejects missing or malformed required collections', () {
      for (final field in ['following_teams', 'calendar']) {
        final missing = _homeJson()..remove(field);
        final malformed = _homeJson()..[field] = 'not-a-list';

        expect(
          () => ApiHomeResponse.fromJson(missing),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(field),
            ),
          ),
        );
        expect(
          () => ApiHomeResponse.fromJson(malformed),
          throwsFormatException,
        );
      }
    });

    test('rejects malformed collection entries', () {
      final malformedTeam = _homeJson()
        ..['following_teams'] = ['not-an-object'];
      final malformedFixture = _homeJson()..['calendar'] = [8];

      expect(
        () => ApiHomeResponse.fromJson(malformedTeam),
        throwsFormatException,
      );
      expect(
        () => ApiHomeResponse.fromJson(malformedFixture),
        throwsFormatException,
      );
    });

    test('requires nullable object fields to be present or null', () {
      for (final field in ['favorite_team', 'next_match', 'last_match']) {
        final missing = _homeJson()..remove(field);
        final malformed = _homeJson()..[field] = [];

        expect(
          () => ApiHomeResponse.fromJson(missing),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(field),
            ),
          ),
        );
        expect(
          () => ApiHomeResponse.fromJson(malformed),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, dynamic> _homeJson() {
  return {
    'favorite_team': _teamJson(8, 'Liverpool', 'LIV'),
    'following_teams': [
      _teamJson(8, 'Liverpool', 'LIV'),
      _teamJson(19, 'Arsenal', 'ARS'),
    ],
    'next_match': _fixtureJson(1001, 'upcoming'),
    'last_match': _fixtureJson(1002, 'past'),
    'calendar': [_fixtureJson(1003, 'live')],
  };
}

Map<String, dynamic> _teamJson(int id, String name, String shortCode) {
  return {
    'team_id': id,
    'name': name,
    'short_code': shortCode,
    'image_path': 'https://cdn.example/$id.png',
  };
}

Map<String, dynamic> _fixtureJson(int fixtureId, String status) {
  return {
    'fixture_id': fixtureId,
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
    'state_id': 1,
    'state_code': 'NS',
    'state_name': 'Not Started',
    'status': status,
    'starting_at': '2026-08-29 14:00:00',
    'home_team_id': 8,
    'away_team_id': 19,
    'home_score': status == 'past' ? 2 : null,
    'away_score': status == 'past' ? 1 : null,
    'home_penalty_score': null,
    'away_penalty_score': null,
    'home_team_name': 'Liverpool',
    'away_team_name': 'Arsenal',
    'home_team_logo': 'https://cdn.example/8.png',
    'away_team_logo': 'https://cdn.example/19.png',
  };
}
