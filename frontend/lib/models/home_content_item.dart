import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/date_labels.dart';

String contentTimeLabel(DateTime? publishedAt,
        {String language = 'en', DateTime? now}) =>
    relativeTimeLabel(publishedAt,
        locale: Locale(language.split(RegExp('[-_]')).first),
        now: now,
        absoluteAfter: const Duration(days: 14));

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
