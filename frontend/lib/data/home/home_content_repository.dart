import 'package:onetouch/models/home_content.dart';

/// Domain-facing boundary for Home highlights and news.
///
/// 뉴스는 팀별 API, 하이라이트는 기존 피드에서 불러와요.
abstract interface class HomeContentRepository {
  /// 뉴스는 예시 기사로 채우지 않아요. 하이라이트의 기존 표시만 유지해요.
  HomeContent get fallback;

  Future<HomeContent> loadForTeam(int favoriteTeamId);
}
