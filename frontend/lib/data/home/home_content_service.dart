import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/home/home_content_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/data/home/mock/home_content_catalog.dart';
import 'package:onetouch/data/teams/mock/team_highlight_catalog.dart';
import 'package:onetouch/models/home_content.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:xml/xml.dart';

class HomeContentService implements HomeContentRepository {
  HomeContentService({
    http.Client? client,
    required this.newsRepository,
    required this.languageCode,
  }) : _client = client ?? http.Client();
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client _client;
  final NewsRepository newsRepository;
  final String Function() languageCode;

  @override
  HomeContent get fallback => HomeContent(
        highlights: homeContentFallbackItems,
        news: const [],
      );

  @override
  Future<HomeContent> loadForTeam(int favoriteTeamId) async {
    var newsFailed = false;
    final results = await Future.wait([
      fetchHighlights(favoriteTeamId: favoriteTeamId),
      newsRepository
          .loadForTeam(favoriteTeamId, language: languageCode())
          .onError((error, stackTrace) {
        newsFailed = true;
        return <HomeContentItem>[];
      }),
    ]);
    return HomeContent(
      highlights: _withFallbacks(results[0]),
      news: results[1],
      newsFailed: newsFailed,
    );
  }

  List<HomeContentItem> _withFallbacks(List<HomeContentItem> items) {
    final result = items.take(homeContentFallbackItems.length).toList();
    while (result.length < homeContentFallbackItems.length) {
      result.add(homeContentFallbackItems[result.length]);
    }
    return result;
  }

  Future<List<HomeContentItem>> fetchHighlights({
    required int favoriteTeamId,
    int limit = 2,
  }) async {
    final teamSources = highlightsByTeam(favoriteTeamId);
    if (teamSources.isEmpty) return const [];

    final sourceRefs =
        teamSources.map((item) => item.sourceRef).toSet().toList();

    return _fetchHighlightsFromSources(
      sourceRefs,
      sourceCount: sourceRefs.length,
      limit: limit,
      relevantTeamIds: [favoriteTeamId],
    );
  }

  Future<List<HomeContentItem>> _fetchHighlightsFromSources(
    List<String> sourceRefs, {
    required int sourceCount,
    required int limit,
    List<int> relevantTeamIds = const [],
  }) async {
    final feeds = await Future.wait(
      sourceRefs.take(sourceCount).map(_fetchHighlightFeed),
    );
    final items = feeds.expand((feed) => feed).toList();
    final rankedItems = items.asMap().entries.toList()
      ..sort((left, right) {
        final rightScore = _highlightRelevance(
          right.value,
          relevantTeamIds,
        );
        final leftScore = _highlightRelevance(
          left.value,
          relevantTeamIds,
        );
        final scoreComparison = rightScore.compareTo(leftScore);
        return scoreComparison != 0
            ? scoreComparison
            : left.key.compareTo(right.key);
      });
    return rankedItems.map((entry) => entry.value).take(limit).toList();
  }

  int _highlightRelevance(
    HomeContentItem item,
    List<int> teamIds,
  ) {
    final title = item.title.toLowerCase();
    final teamTerms = teamIds
        .map((teamId) => _highlightSearchTerms[teamId] ?? const <String>[])
        .where((terms) => terms.isNotEmpty)
        .toList();
    final matchingTeams =
        teamTerms.where((terms) => terms.any(title.contains)).length;

    return matchingTeams;
  }

  Future<List<HomeContentItem>> _fetchHighlightFeed(String sourceRef) async {
    try {
      final uri = Uri.https(
        'www.youtube.com',
        '/feeds/videos.xml',
        {'playlist_id': sourceRef},
      );
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return const [];

      final document = XmlDocument.parse(response.body);
      return _elementsNamed(document, 'entry')
          .map((entry) {
            final videoId = _firstElementNamed(entry, 'videoId')?.innerText;
            final title = _firstElementNamed(entry, 'title')?.innerText.trim();
            final authorElement = _firstElementNamed(entry, 'author');
            final author = authorElement == null
                ? null
                : _firstElementNamed(authorElement, 'name')?.innerText.trim();
            final publishedAt = DateTime.tryParse(
              _firstElementNamed(entry, 'published')?.innerText.trim() ?? '',
            );
            final thumbnail = _firstElementNamed(entry, 'thumbnail');
            final imageUrl = thumbnail?.getAttribute('url');

            if (videoId == null ||
                videoId.isEmpty ||
                title == null ||
                title.isEmpty ||
                imageUrl == null ||
                imageUrl.isEmpty) {
              return null;
            }

            return HomeContentItem(
              title: title,
              source: author?.isNotEmpty == true ? author! : 'YouTube',
              timeLabel: contentTimeLabel(publishedAt),
              imageUrl: imageUrl,
              destinationUrl: 'https://www.youtube.com/watch?v=$videoId',
            );
          })
          .whereType<HomeContentItem>()
          .toList();
    } on Object {
      return const [];
    }
  }

  void dispose() => _client.close();
}

Iterable<XmlElement> _elementsNamed(XmlNode node, String localName) {
  return node.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == localName);
}

XmlElement? _firstElementNamed(XmlNode node, String localName) {
  return _elementsNamed(node, localName).firstOrNull;
}

const _highlightSearchTerms = <int, List<String>>{
  1: ['west ham united', 'west ham'],
  3: ['sunderland'],
  6: ['tottenham hotspur', 'tottenham', 'spurs'],
  8: ['liverpool'],
  9: ['manchester city', 'man city'],
  11: ['fulham'],
  13: ['everton'],
  14: ['manchester united', 'man united', 'man utd'],
  15: ['aston villa', 'villa'],
  18: ['chelsea'],
  19: ['arsenal'],
  20: ['newcastle united', 'newcastle'],
  27: ['burnley'],
  29: ['wolverhampton wanderers', 'wolverhampton', 'wolves'],
  51: ['crystal palace', 'palace'],
  52: ['afc bournemouth', 'bournemouth'],
  63: ['nottingham forest', 'forest'],
  71: ['leeds united', 'leeds'],
  78: ['brighton & hove albion', 'brighton'],
  236: ['brentford'],
};
