class HomeContentItem {
  final String title;
  final String source;
  // 언어가 바뀌거나 화면을 다시 열면 발행 시각을 기준으로 날짜 문구를 계산해요.
  final DateTime? publishedAt;
  final String? imageUrl;
  final String? destinationUrl;
  final String fallbackAsset;

  const HomeContentItem({
    required this.title,
    required this.source,
    required this.publishedAt,
    this.imageUrl,
    this.destinationUrl,
    this.fallbackAsset = 'assets/highlight1.png',
  });
}
