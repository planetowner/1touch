import 'package:onetouch/models/home_content.dart';
import 'package:onetouch/models/home_content_item.dart';

/// Domain-facing boundary for news and the temporary Match highlight lookup.
///
/// Home highlights now come from `GET /v1/home`. News remains feed-backed
/// because the backend does not provide a news endpoint. Match Details keeps
/// its temporary feed lookup until a fixture-highlight endpoint exists.
abstract interface class HomeContentRepository {
  /// Non-empty local content shown while feeds load or are unavailable.
  HomeContent get fallback;

  Future<List<HomeContentItem>> loadNews();

  Future<HomeContentItem?> loadForMatch({
    required int homeTeamId,
    required int awayTeamId,
  });
}
