import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/home/api/api_news_response.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/news_language.dart';

class ApiNewsRepository implements NewsRepository {
  ApiNewsRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
    DateTime Function()? now,
  })  : _client = client,
        _baseUri = Uri.parse(
            '${apiBaseUri.toString().replaceFirst(RegExp(r'/$'), '')}/'),
        _headers = Map.unmodifiable(requestHeaders),
        _now = now ?? DateTime.now;

  final http.Client _client;
  final Uri _baseUri;
  final Map<String, String> _headers;
  final DateTime Function() _now;

  @override
  Future<List<HomeContentItem>> loadForTeam(
    int teamId, {
    required String language,
  }) async {
    final newsLanguage = newsLanguageForLocale(language);
    final uri = _baseUri.resolve('teams/$teamId/news').replace(
      queryParameters: {'language': newsLanguage},
    );
    final response = await _client.get(uri, headers: {
      'Accept': 'application/json',
      ..._headers,
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw http.ClientException(
          'News request failed: ${response.statusCode}', uri);
    }
    final data = ApiNewsResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
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
              language: newsLanguage, now: _now()),
          imageUrl: article.imageUrl,
          destinationUrl: article.url,
        )));
  }
}
