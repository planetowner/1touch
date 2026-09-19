import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/home/api/api_news_repository.dart';
import 'package:onetouch/models/news_language.dart';

void main() {
  test('requests selected team and locale and preserves Korean text', () async {
    final repository = ApiNewsRepository(
      client: MockClient((request) async {
        expect(request.url.toString(),
            'https://api.example.com/v1/teams/83/news?language=ko');
        expect(request.headers['Authorization'], 'Bearer test');
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'team_id': 83,
              'language': 'ko',
              'items': [_article],
            })),
            200);
      }),
      apiBaseUri: Uri.parse('https://api.example.com/v1'),
      requestHeaders: const {'Authorization': 'Bearer test'},
      now: () => DateTime.utc(2026, 9, 19, 18),
    );
    final items = await repository.loadForTeam(83, language: 'ko-KR');
    expect(items, hasLength(1));
    expect(items.single.title, '바르셀로나 경기 소식');
    expect(items.single.timeLabel, '1시간 전');
    expect(items.single.imageUrl, isNull);
    expect(items.single.destinationUrl, 'https://example.com/article/1');
    expect(() => items.clear(), throwsUnsupportedError);
  });

  test('Japanese and Chinese users use English without fabricated news',
      () async {
    expect(newsLanguageForLocale('zh-CN'), 'en');
    final repository = ApiNewsRepository(
      client: MockClient((request) async {
        expect(request.url.queryParameters['language'], 'en');
        return http.Response('{"team_id":83,"language":"en","items":[]}', 200);
      }),
      apiBaseUri: Uri.parse('https://api.example.com/v1/'),
      requestHeaders: const {},
    );
    expect(await repository.loadForTeam(83, language: 'ja'), isEmpty);
  });

  test('wrong team responses and HTTP failures are not empty successes',
      () async {
    for (final response in [
      http.Response('{"team_id":19,"language":"en","items":[]}', 200),
      http.Response('unavailable', 503),
    ]) {
      final repository = ApiNewsRepository(
        client: MockClient((_) async => response),
        apiBaseUri: Uri.parse('https://api.example.com/v1/'),
        requestHeaders: const {},
      );
      await expectLater(
          repository.loadForTeam(83, language: 'en'), throwsException);
    }
  });
}

const _article = {
  'article_id': 1,
  'title': '바르셀로나 경기 소식',
  'source': '포포투',
  'url': 'https://example.com/article/1',
  'image_url': null,
  'published_at': '2026-09-19T17:00:00Z',
};
