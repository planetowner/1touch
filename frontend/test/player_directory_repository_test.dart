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
