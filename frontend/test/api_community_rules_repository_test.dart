import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/community/api/api_community_repository.dart';
import 'package:onetouch/models/community_rules.dart';

void main() {
  test('loads localized rules through the authenticated endpoint', () async {
    final repository = ApiCommunityRepository(
      api: ApiClient(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/v1/community/rules');
            expect(request.url.queryParameters, {
              'team_id': '9',
              'language': 'ko',
            });
            expect(request.headers['Accept'], 'application/json');
            expect(request.headers['Authorization'], 'Bearer session-token');
            return http.Response(jsonEncode(_rulesJson(language: 'ko')), 200);
          }),
          baseUri: Uri.parse('https://api.1touch.football/v1'),
          requestHeaders: () =>
              const {'Authorization': 'Bearer session-token'}),
    );

    final rules = await repository.loadRules(
      teamId: 9,
      language: CommunityLanguage.korean,
    );

    expect(rules.language, CommunityLanguage.korean);
    expect(rules.title, 'Community Ground Rules');
    expect(rules.items.single.title, 'Keep it about football');
    expect(rules.items.single.body, 'Disagree with the take, not the person.');
    expect(rules.confirmLabel, 'Got it');
    expect(() => rules.items.clear(), throwsUnsupportedError);
  });

  test('maps supported locale parts and falls back to English', () {
    expect(
      CommunityLanguage.fromLocaleParts(languageCode: 'ko'),
      CommunityLanguage.korean,
    );
    expect(
      CommunityLanguage.fromLocaleParts(languageCode: 'JA'),
      CommunityLanguage.japanese,
    );
    expect(
      CommunityLanguage.fromLocaleParts(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
      CommunityLanguage.simplifiedChinese,
    );
    expect(
      CommunityLanguage.fromLocaleParts(
        languageCode: 'zh',
        scriptCode: 'Hant',
      ),
      CommunityLanguage.english,
    );
    expect(
      CommunityLanguage.fromLocaleParts(languageCode: 'fr'),
      CommunityLanguage.english,
    );
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
        language: CommunityLanguage.english,
      ),
      throwsRangeError,
    );
    expect(requests, 0);
  });

  test('rejects failed, malformed, empty, and mismatched responses', () async {
    final responses = <http.Response>[
      http.Response('Forbidden', 403),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({}), 200),
      http.Response(jsonEncode(_rulesJson(items: [])), 200),
      http.Response(jsonEncode(_rulesJson(title: '   ')), 200),
      http.Response(jsonEncode(_rulesJson(language: 'ko')), 200),
      http.Response(jsonEncode(_rulesJson(language: 'es')), 200),
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
          language: CommunityLanguage.english,
        ),
        throwsA(anyOf(isA<http.ClientException>(), isA<FormatException>())),
      );
    }
  });
}

Map<String, dynamic> _rulesJson({
  String language = 'en',
  String title = 'Community Ground Rules',
  List<Map<String, dynamic>>? items,
}) {
  return {
    'rules': {
      'language': language,
      'title': title,
      'items': items ??
          [
            {
              'title': 'Keep it about football',
              'body': 'Disagree with the take, not the person.',
            },
          ],
      'confirm_label': 'Got it',
    },
  };
}
