import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:onetouch/data/teams/mock/team_highlight_catalog.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:xml/xml.dart';

class HomeContentService {
  HomeContentService({http.Client? client, Random? random})
      : _client = client ?? http.Client(),
        _random = random ?? Random();

  static final Uri _newsFeed =
      Uri.parse('https://feeds.bbci.co.uk/sport/football/rss.xml');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client _client;
  final Random _random;

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

  Future<HomeContentItem?> fetchMatchHighlight({
    required int homeTeamId,
    required int awayTeamId,
  }) async {
    final teamSources = [
      ...highlightsByTeam(homeTeamId),
      ...highlightsByTeam(awayTeamId),
    ];
    if (teamSources.isEmpty) return null;

    final sourceRefs =
        teamSources.map((item) => item.sourceRef).toSet().toList();
    final items = await _fetchHighlightsFromSources(
      sourceRefs,
      sourceCount: sourceRefs.length,
      limit: 1,
      relevantTeamIds: [homeTeamId, awayTeamId],
      preferExactMatch: true,
    );
    return items.firstOrNull;
  }

  Future<List<HomeContentItem>> _fetchHighlightsFromSources(
    List<String> sourceRefs, {
    required int sourceCount,
    required int limit,
    List<int> relevantTeamIds = const [],
    bool preferExactMatch = false,
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
          preferExactMatch: preferExactMatch,
        );
        final leftScore = _highlightRelevance(
          left.value,
          relevantTeamIds,
          preferExactMatch: preferExactMatch,
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
    List<int> teamIds, {
    required bool preferExactMatch,
  }) {
    final title = item.title.toLowerCase();
    final teamTerms = teamIds
        .map((teamId) => _highlightSearchTerms[teamId] ?? const <String>[])
        .where((terms) => terms.isNotEmpty)
        .toList();
    final matchingTeams =
        teamTerms.where((terms) => terms.any(title.contains)).length;

    if (preferExactMatch &&
        teamTerms.length > 1 &&
        matchingTeams == teamTerms.length) {
      return 100 + matchingTeams;
    }
    return matchingTeams;
  }

  Future<List<HomeContentItem>> fetchNews({int limit = 2}) async {
    try {
      final response = await _client.get(_newsFeed).timeout(_requestTimeout);
      if (response.statusCode != 200) return const [];

      final document = XmlDocument.parse(response.body);
      final items = _elementsNamed(document, 'item')
          .map((item) {
            final thumbnail = _firstElementNamed(item, 'thumbnail');
            final imageUrl = thumbnail?.getAttribute('url');
            final title = _firstElementNamed(item, 'title')?.innerText.trim();
            final destinationUrl =
                _firstElementNamed(item, 'link')?.innerText.trim();
            final publishedAt = _parseBbcDate(
              _firstElementNamed(item, 'pubDate')?.innerText.trim(),
            );

            if (title == null ||
                title.isEmpty ||
                imageUrl == null ||
                imageUrl.isEmpty) {
              return null;
            }

            return HomeContentItem(
              title: title,
              source: 'BBC Sport',
              timeLabel: _relativeTime(publishedAt),
              imageUrl: imageUrl,
              destinationUrl: destinationUrl,
            );
          })
          .whereType<HomeContentItem>()
          .toList()
        ..shuffle(_random);

      return items.take(limit).toList();
    } on Object {
      return const [];
    }
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
              timeLabel: _relativeTime(publishedAt),
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

  DateTime? _parseBbcDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US')
          .parseUtc(value);
    } on FormatException {
      return null;
    }
  }

  String _relativeTime(DateTime? publishedAt) {
    if (publishedAt == null) return 'Latest';
    final difference = DateTime.now().toUtc().difference(publishedAt.toUtc());
    if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(publishedAt.toLocal());
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
