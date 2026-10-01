import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/community/api/api_community_repository.dart';

void main() {
  test('loads message keys through the authenticated endpoint', () async {
    final repository = ApiCommunityRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/community/rules');
            expect(request.url.queryParameters, {
              'team_id': '9',
            });
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_rulesJson()), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final rules = await repository.loadRules(
      teamId: 9,
    );

    expect(rules.title, 'Community Ground Rules');
    expect(rules.items.single.title, 'Keep it about football');
    expect(rules.items.single.body, 'Disagree with the take, not the person.');
    expect(() => rules.items.clear(), throwsUnsupportedError);
  });

  test('rejects an invalid team ID before requesting rules', () async {
    var requests = 0;
    final repository = ApiCommunityRepository(
      api: ApiClient(
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () => const {}),
    );

    await expectLater(
      repository.loadRules(
        teamId: 0,
      ),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects failed, malformed, and empty responses', () async {
    final responses = <http.Response>[
      http.Response('Forbidden', 403),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({}), 200),
      http.Response(jsonEncode(_rulesJson(items: [])), 200),
      http.Response(jsonEncode(_rulesJson(title: '   ')), 200),
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
        repository.loadRules(
          teamId: 9,
        ),
        throwsA(anyOf(isA<http.ClientException>(), isA<FormatException>())),
      );
    }
  });
}

Map<String, dynamic> _rulesJson({
  String title = 'Community Ground Rules',
  List<Map<String, dynamic>>? items,
}) {
  return {
    'rules': {
      'title': title,
      'items': items ??
          [
            {
              'title': 'Keep it about football',
              'body': 'Disagree with the take, not the person.',
            },
          ],
    },
  };
}
