import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/players/api/api_player_club_history_repository.dart';
import 'package:onetouch/data/players/player_club_history_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The session-aware client injects the latest login token for every request.
final PlayerClubHistoryRepository playerClubHistoryRepository =
    ApiPlayerClubHistoryRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
