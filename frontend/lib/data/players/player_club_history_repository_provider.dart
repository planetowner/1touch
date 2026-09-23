import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/players/api/api_player_club_history_repository.dart';
import 'package:onetouch/data/players/player_club_history_repository.dart';

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The current API configuration captures the environment session token when
/// this library is initialized. Replace that static header source with the
/// authenticated session when saved-login restoration is implemented.
final PlayerClubHistoryRepository playerClubHistoryRepository =
    ApiPlayerClubHistoryRepository(
  api: apiClient,
);
