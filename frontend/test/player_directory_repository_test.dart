import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'support/player_directory_fixture.dart';

void main() {
  test(
      'current ranking has no season parameter and preserves paging and filters',
      () async {
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/v1/players/ranking-current');
            expect(request.url.queryParameters, {
              'competition_id': '8',
              'position': 'DF',
              'offset': '100',
              'limit': '100'
            });
            expect(request.headers['Authorization'], 'Bearer test');
            return http.Response(
                jsonEncode({
                  'season_name': '2026/2027',
                  'total': 101,
                  'leagues': [
                    {
                      'competition_id': 8,
                      'name': 'Premier League',
                      'available_players': 101
                    }
                  ],
                  'items': [
                    {
                      'player_id': 123456,
                      'name': 'Real name',
                      'image': null,
                      'position': 'DF',
                      'rank': 101,
                      'display_score': 74.5,
                      'average_rating': 7.21,
                      'rated_matches': 8
                    }
                  ]
                }),
                200);
          }),
          baseUri: Uri.parse('https://example.test/v1/'),
          requestHeaders: () => const {'Authorization': 'Bearer test'}),
    );
    final result =
        await repository.ranking(league: 8, position: 'DF', offset: 100);
    expect(result.items.single.id, 123456);
    expect(result.items.single.score, 74.5);
  });
  test('ones to watch includes current team and jersey in one request',
      () async {
    var requests = 0;
    final repository = ApiPlayerDirectoryRepository(
      api: ApiClient(
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/v1/players/ones-to-watch');
          return http.Response(
              jsonEncode({
                'items': [
                  {
                    'player_id': 7,
                    'name': 'Watch player',
                    'image': null,
                    'jersey_number': 17,
                    'team_id': 7980,
                    'team_name': 'Atlético de Madrid',
                    'recent_average': 8.4,
                    'previous_average': 6.2,
                    'change': 2.2,
                  }
                ]
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
        baseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: () => const {},
      ),
    );

    final result = await repository.watch();

    expect(result.single.jerseyNumber, 17);
    expect(result.single.teamId, 7980);
    expect(result.single.teamName, 'Atlético de Madrid');
    expect(requests, 1);
  });
  test('favorite toggle first loads order and leaves list unchanged on failure',
      () async {
    final repository = FakeFollowingPlayersRepository();
    final controller = PlayerFollowingController(repository: repository);
    await controller.toggle(2);
    expect(repository.saved, [1, 2]);
    expect(controller.players.last.name, 'Saved player 2');
    repository.fail = true;
    await expectLater(controller.toggle(1), throwsStateError);
    expect(controller.players.map((p) => p.playerId), [1, 2]);
    repository.fail = false;
    await controller.load();
    expect(controller.error, isNull);
  });
}
