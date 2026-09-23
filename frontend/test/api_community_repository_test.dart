import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/community/api/api_community_repository.dart';

void main() {
  test('loads a Bearer-authenticated follower count for the requested team',
      () async {
    final repository = ApiCommunityRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/community/followers');
            expect(request.url.queryParameters, {'team_id': '9'});
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(
              jsonEncode({'team_id': 9, 'follower_count': 1250}),
              200,
            );
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    expect(await repository.loadFollowerCount(teamId: 9), 1250);
  });

  test('rejects an invalid team ID before making a request', () async {
    var requests = 0;
    final repository = ApiCommunityRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1/'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadFollowerCount(teamId: 0),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects failed and malformed responses', () async {
    final responses = <http.Response>[
      http.Response('Unauthorized', 401),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({'team_id': 9}), 200),
      http.Response(
        jsonEncode({'team_id': 9, 'follower_count': -1}),
        200,
      ),
      http.Response(
        jsonEncode({'team_id': 83, 'follower_count': 1}),
        200,
      ),
    ];
    var requestIndex = 0;
    final repository = ApiCommunityRepository(
      api: ApiClient(
          client: MockClient((_) async => responses[requestIndex++]),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    for (var index = 0; index < responses.length; index++) {
      await expectLater(
        repository.loadFollowerCount(teamId: 9),
        throwsA(anyOf(isA<http.ClientException>(), isA<FormatException>())),
      );
    }
  });
}
