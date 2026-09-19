import 'package:onetouch/models/home_content_item.dart';

abstract interface class NewsRepository {
  Future<List<HomeContentItem>> loadForTeam(
    int teamId, {
    required String language,
  });
}
