import 'package:flutter/foundation.dart';
import 'package:onetouch/core/user_preferences.dart';

/// Single shared source of truth for the current user's favorite team.
///
/// HomeScreen, the bottom-nav Team tab, and CommunityScreen all read from
/// this instead of independently re-querying mock data, so switching the
/// favorite team in one place is reflected everywhere else.
class FavoriteTeam {
  FavoriteTeam._();

  static ValueNotifier<int> get id => currentUserPreferences.favoriteTeamId;
}
