class ApiNewsArticle {
  const ApiNewsArticle({
    required this.title,
    required this.source,
    required this.url,
    required this.imageUrl,
    required this.publishedAt,
  });

  final String title;
  final String source;
  final String url;
  final String? imageUrl;
  final DateTime publishedAt;

  factory ApiNewsArticle.fromJson(Map<String, dynamic> json) => ApiNewsArticle(
        title: json['title'] as String,
        source: json['source'] as String,
        url: json['url'] as String,
        imageUrl: json['image_url'] as String?,
        publishedAt: DateTime.parse(json['published_at'] as String).toUtc(),
      );
}

class ApiNewsResponse {
  ApiNewsResponse({
    required this.teamId,
    required this.language,
    required List<ApiNewsArticle> items,
  }) : items = List.unmodifiable(items);

  final int teamId;
  final String language;
  final List<ApiNewsArticle> items;

  factory ApiNewsResponse.fromJson(Map<String, dynamic> json) =>
      ApiNewsResponse(
        teamId: json['team_id'] as int,
        language: json['language'] as String,
        items: (json['items'] as List)
            .map(
                (item) => ApiNewsArticle.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
