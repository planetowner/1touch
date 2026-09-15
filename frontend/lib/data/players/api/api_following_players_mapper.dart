import 'package:onetouch/data/players/api/api_following_players_response.dart';
import 'package:onetouch/models/following_player.dart';

FollowingPlayer followingPlayerFromApiResponse(
  ApiFollowingPlayerResponse response,
) {
  if (response.playerId < 1) {
    throw FormatException(
      'Expected a positive following-player ID, got ${response.playerId}.',
    );
  }

  final name = response.name.trim();
  if (name.isEmpty) {
    throw const FormatException(
      'Expected a non-empty following-player name.',
    );
  }

  return FollowingPlayer(
    playerId: response.playerId,
    name: name,
    imagePath: response.imagePath,
  );
}
