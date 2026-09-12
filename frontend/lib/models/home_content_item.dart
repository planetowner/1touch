class HomeContentItem {
  final String title;
  final String source;
  final String timeLabel;
  final String? imageUrl;
  final String? destinationUrl;
  final String fallbackAsset;

  const HomeContentItem({
    required this.title,
    required this.source,
    required this.timeLabel,
    this.imageUrl,
    this.destinationUrl,
    this.fallbackAsset = 'assets/highlight1.png',
  });
}
