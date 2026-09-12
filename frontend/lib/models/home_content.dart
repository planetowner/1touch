import 'package:onetouch/models/home_content_item.dart';

class HomeContent {
  HomeContent({
    required List<HomeContentItem> highlights,
    required List<HomeContentItem> news,
  })  : highlights = List.unmodifiable(highlights),
        news = List.unmodifiable(news);

  final List<HomeContentItem> highlights;
  final List<HomeContentItem> news;
}
