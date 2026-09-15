import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/teams/api/api_following_teams_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';

void main() {
  test('loads and caches following teams in backend order', () async {
    final repository = ApiFollowingTeamsRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/users/me/following/teams');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(jsonEncode(_teamsJson()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final teams = await repository.load();

    expect(teams.map((team) => team.teamId), [83, 19]);
    expect(teams.first.name, 'FC Barcelona');
    expect(teams.last.imagePath, isNull);
    expect(repository.cachedTeams.value, same(teams));
    expect(() => teams.clear(), throwsUnsupportedError);
  });

  test('PUT sends the selection and re-fetches authoritative order', () async {
    var requestIndex = 0;
    final repository = ApiFollowingTeamsRepository(
      client: MockClient((request) async {
        requestIndex++;
        expect(request.url.path, '/v1/users/me/following/teams');
        expect(request.headers['Authorization'], 'Bearer session-token');
        if (requestIndex == 1) {
          expect(request.method, 'PUT');
          expect(request.headers['Content-Type'], 'application/json');
          expect(jsonDecode(request.body), {
            'teamIds': [19, 83],
            'favoriteTeamId': 19,
          });
          return http.Response(jsonEncode({'ok': true}), 200);
        }

        expect(request.method, 'GET');
        return http.Response(jsonEncode(_teamsJson().reversed.toList()), 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1/'),
      requestHeaders: const {'Authorization': 'Bearer session-token'},
    );

    final teams = await repository.replaceFollowing(
      teamIds: [19, 83],
      favoriteTeamId: 19,
    );

    expect(requestIndex, 2);
    expect(teams.map((team) => team.teamId), [19, 83]);
    expect(repository.cachedTeams.value, same(teams));
  });

  test('validates the complete selection before requesting', () async {
    var requests = 0;
    final repository = ApiFollowingTeamsRepository(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.replaceFollowing(teamIds: const [], favoriteTeamId: 83),
      throwsRangeError,
    );
    await expectLater(
      repository.replaceFollowing(
        teamIds: const [1, 2, 3, 4, 5, 6],
        favoriteTeamId: 1,
      ),
      throwsRangeError,
    );
    await expectLater(
      repository.replaceFollowing(
        teamIds: const [83, 0],
        favoriteTeamId: 83,
      ),
      throwsRangeError,
    );
    await expectLater(
      repository.replaceFollowing(
        teamIds: const [83, 83],
        favoriteTeamId: 83,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.replaceFollowing(
        teamIds: const [83, 19],
        favoriteTeamId: 9,
      ),
      throwsArgumentError,
    );
    expect(requests, 0);
  });

  test('surfaces a typed favorite-team cooldown', () async {
    final repository = ApiFollowingTeamsRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': {
              'message': 'Favorite team can be changed later',
              'available_at': '2026-09-20T12:30:00Z',
            },
          }),
          409,
        ),
      ),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.replaceFollowing(
        teamIds: const [83, 19],
        favoriteTeamId: 19,
      ),
      throwsA(
        isA<FavoriteTeamCooldownException>()
            .having((error) => error.message, 'message', contains('later'))
            .having(
              (error) => error.availableAt,
              'availableAt',
              DateTime.utc(2026, 9, 20, 12, 30),
            ),
      ),
    );
    expect(repository.cachedTeams.value, isEmpty);
  });

  test('rejects malformed and unsuccessful responses without caching',
      () async {
    final responses = [
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode({}), 200),
      http.Response(jsonEncode([1]), 200),
      http.Response(
        jsonEncode([
          _teamJson(83, 'FC Barcelona'),
          _teamJson(83, 'Duplicate Barcelona'),
        ]),
        200,
      ),
    ];
    var requestIndex = 0;
    final repository = ApiFollowingTeamsRepository(
      client: MockClient((_) async => responses[requestIndex++]),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(repository.load(), throwsA(isA<http.ClientException>()));
    for (var index = 1; index < responses.length; index++) {
      await expectLater(repository.load(), throwsFormatException);
    }
    expect(repository.cachedTeams.value, isEmpty);
  });

  test('does not re-fetch or change cache after a failed PUT response',
      () async {
    final responses = [
      http.Response('Server error', 500),
      http.Response(jsonEncode({'ok': false}), 200),
    ];
    var requestIndex = 0;
    final repository = ApiFollowingTeamsRepository(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        return responses[requestIndex++];
      }),
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.replaceFollowing(
        teamIds: const [83],
        favoriteTeamId: 83,
      ),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.replaceFollowing(
        teamIds: const [83],
        favoriteTeamId: 83,
      ),
      throwsFormatException,
    );
    expect(requestIndex, 2);
    expect(repository.cachedTeams.value, isEmpty);
  });
}

List<Map<String, dynamic>> _teamsJson() => [
      _teamJson(83, 'FC Barcelona'),
      _teamJson(19, 'Arsenal', imagePath: null),
    ];

Map<String, dynamic> _teamJson(
  int teamId,
  String name, {
  String? imagePath = 'https://cdn.example.com/team.png',
}) =>
    {
      'team_id': teamId,
      'name': name,
      'short_code': null,
      'image_path': imagePath,
    };
