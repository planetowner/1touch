import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/highlights/fixture_highlight_repository.dart';
import 'package:onetouch/models/fixture_highlight.dart';

class ApiFixtureHighlightRepository implements FixtureHighlightRepository {
  ApiFixtureHighlightRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<FixtureHighlight?> loadForFixture(int fixtureId) async {
    // 실제 시청 국가를 추정하지 않고 외부 YouTube에서 재생 제한을 처리해요.
    final uri = _api.baseUri.resolve('fixtures/$fixtureId/highlights');
    final response = await _api.get(
      uri,
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
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
