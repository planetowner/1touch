import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/players/api/api_player_club_history_repository.dart';
import 'package:onetouch/data/players/player_club_history_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The current API configuration captures the environment session token when
/// this library is initialized. Replace that static header source with the
/// authenticated session when saved-login restoration is implemented.
final PlayerClubHistoryRepository playerClubHistoryRepository =
    ApiPlayerClubHistoryRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
