import 'package:flutter/foundation.dart';
import 'package:onetouch/core/user_preferences.dart';

/// 저장된 최애팀이에요. 탭에서 탐색 중인 팀은 viewedTeamId로 따로 관리해요.
class FavoriteTeam {
  FavoriteTeam._();

  static ValueNotifier<int> get id => currentUserPreferences.favoriteTeamId;
}
