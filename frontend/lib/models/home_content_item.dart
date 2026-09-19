import 'package:intl/intl.dart';

String contentTimeLabel(DateTime? publishedAt,
    {String language = 'en', DateTime? now}) {
  final korean = language == 'ko';
  if (publishedAt == null) {
    return korean ? '최근' : 'Latest';
  }
  final difference =
      (now ?? DateTime.now()).toUtc().difference(publishedAt.toUtc());
  if (difference.inMinutes < 1) {
    return korean ? '방금 전' : 'Just now';
  }
  if (difference.inMinutes < 60) {
    return korean
        ? '${difference.inMinutes}분 전'
        : '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return korean ? '${difference.inHours}시간 전' : '${difference.inHours}h ago';
  }
  if (difference.inDays < 14) {
    return korean ? '${difference.inDays}일 전' : '${difference.inDays}d ago';
  }
  return DateFormat(korean ? 'M월 d일' : 'MMM d', 'en_US')
      .format(publishedAt.toLocal());
}

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
