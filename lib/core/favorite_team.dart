import 'package:flutter/foundation.dart';
import '../models/mock_data.dart';

/// Single shared source of truth for the current user's favorite team.
///
/// HomeScreen, the bottom-nav Team tab, and CommunityScreen all read from
/// this instead of independently re-querying mock data, so switching the
/// favorite team in one place is reflected everywhere else.
class FavoriteTeam {
  FavoriteTeam._();

  static final ValueNotifier<int> id = ValueNotifier<int>(
    mockUserProfiles.firstWhere((p) => p.userId == 1001).favoriteTeamId ?? 83,
  );
}