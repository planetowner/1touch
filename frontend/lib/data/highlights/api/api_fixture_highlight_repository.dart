import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/highlights/fixture_highlight_repository.dart';
import 'package:onetouch/models/fixture_highlight.dart';

class ApiFixtureHighlightRepository implements FixtureHighlightRepository {
  ApiFixtureHighlightRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = apiBaseUri.toString().endsWith('/')
            ? apiBaseUri
            : Uri.parse('$apiBaseUri/'),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

  @override
  Future<FixtureHighlight?> loadForFixture(int fixtureId) async {
    // 실제 시청 국가를 추정하지 않고 외부 YouTube에서 재생 제한을 처리해요.
    final uri = _apiBaseUri.resolve('fixtures/$fixtureId/highlights');
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', ..._requestHeaders},
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Fixture highlights request failed with status ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['fixture_id'] != fixtureId) {
      throw const FormatException(
          'Highlight response belongs to another fixture.');
    }
    final items = decoded['items'] as List<dynamic>;
    if (items.isEmpty) return null;
    final item = items.single as Map<String, dynamic>;
    final match = item['match'] as Map<String, dynamic>;
    // 같은 두 팀의 다른 시즌·다른 라운드 영상도 현재 경기로 표시하지 않아요.
    if (match['fixture_id'] != fixtureId) {
      throw const FormatException(
          'Highlight video belongs to another fixture.');
    }
    return FixtureHighlight(
      fixtureId: fixtureId,
      videoUrl: item['video_url'] as String,
      title: item['title'] as String,
      thumbnailUrl: item['thumbnail_url'] as String?,
    );
  }
}
