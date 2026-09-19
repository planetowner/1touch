import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/highlights/api/api_fixture_highlight_repository.dart';

void main() {
  test('requests the exact fixture without guessing the viewer country',
      () async {
    final repository = ApiFixtureHighlightRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/v1/fixtures/19722166/highlights');
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['Authorization'], 'Bearer test-session');
        return http.Response(jsonEncode(_response()), 200);
      }),
      apiBaseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: const {'Authorization': 'Bearer test-session'},
    );
    final item = await repository.loadForFixture(19722166);
    expect(item!.fixtureId, 19722166);
    expect(item.videoUrl, 'https://www.youtube.com/watch?v=NLfa3K9ro5Y');
    expect(item.title, 'Man United 0-1 Man City');
  });

  test('does not substitute another video when this fixture has none',
      () async {
    final repository = ApiFixtureHighlightRepository(
      client: MockClient((_) async =>
          http.Response(jsonEncode({..._response(), 'items': []}), 200)),
      apiBaseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: const {},
    );
    expect(await repository.loadForFixture(19722166), isNull);
  });

  test('rejects videos from a different fixture, including the same teams',
      () async {
    for (final mismatch in ['envelope', 'video']) {
      final body = _response();
      if (mismatch == 'envelope') {
        body['fixture_id'] = 123;
      } else {
        ((body['items'] as List).single as Map)['match'] = {'fixture_id': 123};
      }
      final repository = ApiFixtureHighlightRepository(
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
        apiBaseUri: Uri.parse('https://example.test/v1/'),
        requestHeaders: const {},
      );
      await expectLater(
          repository.loadForFixture(19722166), throwsFormatException);
    }
  });

  test('preserves missing thumbnails and reports failed requests', () async {
    final body = _response();
    ((body['items'] as List).single as Map)['thumbnail_url'] = null;
    var calls = 0;
    final repository = ApiFixtureHighlightRepository(
      client: MockClient((_) async => ++calls == 1
          ? http.Response(jsonEncode(body), 200)
          : http.Response('Unavailable', 503)),
      apiBaseUri: Uri.parse('https://example.test/v1/'),
      requestHeaders: const {},
    );
    expect((await repository.loadForFixture(19722166))!.thumbnailUrl, isNull);
    await expectLater(repository.loadForFixture(19722166),
        throwsA(isA<http.ClientException>()));
  });
}

Map<String, dynamic> _response() => {
      'fixture_id': 19722166,
      'viewer_country': null,
      'updated_at': '2026-09-19T18:00:48Z',
      'items': [
        <String, dynamic>{
          'video_url': 'https://www.youtube.com/watch?v=NLfa3K9ro5Y',
          'title': 'Man United 0-1 Man City',
          'thumbnail_url':
              'https://i.ytimg.com/vi/NLfa3K9ro5Y/maxresdefault.jpg',
          'match': {'fixture_id': 19722166},
        },
      ],
    };
