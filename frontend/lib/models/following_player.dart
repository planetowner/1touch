import 'package:flutter/foundation.dart';

/// Minimal player identity returned by the current user's following endpoint.
///
/// This intentionally remains separate from the existing `Player` model,
/// whose current frontend catalogue contains mock-only profile, ranking, and
/// statistics fields.
@immutable
class FollowingPlayer {
  const FollowingPlayer({
    required this.playerId,
    required this.name,
    required this.imagePath,
  });

  final int playerId;
  final String name;
  final String? imagePath;
}
