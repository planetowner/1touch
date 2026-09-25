import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/home/api/api_home_mapper.dart';
import 'package:onetouch/data/home/api/api_home_highlights_response.dart';
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
          highlights: ApiTeamHighlightsResponse.fromJson(_highlightsJson()),
        ),
      );

      expect(home.favoriteTeam.teamId, 8);
      expect(home.favoriteTeam.name, 'Liverpool');
      expect(home.followingTeams.map((team) => team.teamId), [8, 19]);
      expect(home.nextMatch?.fixtureId, 1001);
      expect(home.lastMatch?.fixtureId, 1002);
      expect(home.calendar.single.fixture.fixtureId, 1003);
      expect(home.calendar.single.opponent.teamId, 19);
      expect(home.calendar.single.opponent.name, 'Arsenal');
      expect(
        home.calendar.single.opponent.imagePath,
        'https://cdn.example/19.png',
      );
      expect(home.liveMatch?.fixtureId, 1003);
      expect(home.highlights.single.title, 'Liverpool highlights');
      expect(home.highlights.single.source, 'Liverpool FC');
      expect(home.highlights.single.publishedAt, DateTime.utc(2026, 9, 18, 20));
      expect(home.highlights.single.imageUrl, isNull);
      expect(
        home.highlights.single.destinationUrl,
        'https://www.youtube.com/watch?v=video-1',
      );
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

    test('rejects a calendar fixture unrelated to the favorite team', () {
      expect(
        () => homeDataFromApiResponse(
          _response(
            calendar: [
              _fixture(
                1003,
                FixtureStatus.upcoming,
                homeTeamId: 2,
                awayTeamId: 19,
              ),
            ],
          ),
        ),
        throwsStateError,
      );
    });

    test('rejects highlights for a team other than the favorite team', () {
      final highlights = ApiTeamHighlightsResponse.fromJson(_highlightsJson());

      expect(
        () => homeDataFromApiResponse(
          _response(
            favoriteTeam: _team(19, 'Arsenal', 'ARS'),
            highlights: highlights,
          ),
        ),
        throwsStateError,
      );
    });

    test('returns immutable domain collections', () {
      final home = homeDataFromApiResponse(
        _response(calendar: [_fixture(1003, FixtureStatus.live)]),
      );

      expect(() => home.followingTeams.clear(), throwsUnsupportedError);
      expect(() => home.calendar.clear(), throwsUnsupportedError);
      expect(() => home.highlights.clear(), throwsUnsupportedError);
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
  ApiTeamHighlightsResponse? highlights,
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
    highlights: highlights,
  );
}

Map<String, dynamic> _highlightsJson() => {
      'team_id': 8,
      'viewer_country': 'US',
      'updated_at': null,
      'items': [
        {
          'video_id': 'video-1',
          'video_url': 'https://www.youtube.com/watch?v=video-1',
          'title': 'Liverpool highlights',
          'thumbnail_url': null,
          'published_at': '2026-09-18T20:00:00Z',
          'duration_seconds': 420,
          'channel_id': 'channel-1',
          'channel_name': 'Liverpool FC',
          'source_type': 'club',
          'is_extended': false,
          'embeddable': true,
          'match': {
            'match_key': 'sportmonks:1003',
            'fixture_id': null,
            'competition_key': 'sportmonks:8',
            'competition_name': 'Premier League',
            'season_name': '2026/2027',
            'starting_at': '2026-09-18T14:00:00Z',
            'home': {'team_id': 8, 'name': 'Liverpool'},
            'away': {'team_id': null, 'name': 'Arsenal'},
            'record_source': 'sportmonks',
            'record_url': 'https://example.test/fixtures/1003',
          },
        },
      ],
    };

ApiTeamResponse _team(int id, String name, String shortCode) {
  return ApiTeamResponse(
    teamId: id,
    name: name,
    shortCode: shortCode,
    imagePath: 'https://cdn.example/$id.png',
  );
}

ApiFixtureResponse _fixture(
  int fixtureId,
  FixtureStatus status, {
  int homeTeamId = 8,
  int awayTeamId = 19,
}) {
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
    homeTeamId: homeTeamId,
    awayTeamId: awayTeamId,
    homeScore: status == FixtureStatus.past ? 2 : null,
    awayScore: status == FixtureStatus.past ? 1 : null,
    homePenaltyScore: null,
    awayPenaltyScore: null,
    homeTeamName: homeTeamId == 8 ? 'Liverpool' : 'Other FC',
    awayTeamName: 'Arsenal',
    homeTeamLogo: 'https://cdn.example/8.png',
    awayTeamLogo: 'https://cdn.example/19.png',
  );
}
