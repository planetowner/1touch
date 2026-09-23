import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/home/api/api_news_response.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/news_language.dart';

class ApiNewsRepository implements NewsRepository {
  ApiNewsRepository({
    required ApiClient api,
    DateTime Function()? now,
  })  : _api = api,
        _now = now ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _now;

  @override
  Future<List<HomeContentItem>> loadForTeam(
    int teamId, {
    required String language,
  }) async {
    final newsLanguage = newsLanguageForLocale(language);
    final uri = _api.baseUri.resolve('teams/$teamId/news').replace(
      queryParameters: {'language': newsLanguage},
    );
    final response = await _api.get(uri).timeout(const Duration(seconds: 8));
    final data = ApiNewsResponse.fromJson(
      _api.decodeJson<Map<String, dynamic>>(response),
    );
    if (data.teamId != teamId ||
        data.language != newsLanguage ||
        data.items.length > 3) {
      throw const FormatException(
          'News response does not match the requested team or language.');
    }
    return List.unmodifiable(data.items.map((article) => HomeContentItem(
          title: article.title,
          source: article.source,
          timeLabel: contentTimeLabel(article.publishedAt,
              language: language, now: _now()),
          imageUrl: article.imageUrl,
          destinationUrl: article.url,
        )));
  }
}
