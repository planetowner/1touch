import 'package:onetouch/models/home_content.dart';
import 'package:onetouch/models/home_content_item.dart';

/// Domain-facing boundary for Home highlights and news.
///
/// These feeds are separate from `GET /v1/home` because that endpoint does
/// not currently provide either content type. Replace the feed-backed
/// implementation when the backend exposes an equivalent contract.
abstract interface class HomeContentRepository {
  /// Non-empty local content shown while feeds load or are unavailable.
  HomeContent get fallback;

  Future<HomeContent> loadForTeam(int favoriteTeamId);

  Future<HomeContentItem?> loadForMatch({
    required int homeTeamId,
    required int awayTeamId,
  });
}
