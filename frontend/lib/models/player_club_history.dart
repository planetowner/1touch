import 'package:flutter/foundation.dart';

@immutable
class PlayerClubHistoryEntry {
  const PlayerClubHistoryEntry({
    required this.teamId,
    required this.teamName,
    required this.teamImage,
    required this.startDate,
    required this.endDate,
  });

  final int teamId;
  final String? teamName;
  final String? teamImage;

  /// Date-only provider value. Null means the arrival date is not known.
  final DateTime? startDate;

  /// Date-only provider value. Null means no departure was confirmed; it does
  /// not independently prove that this is the player's current club.
  final DateTime? endDate;
}

@immutable
class PlayerClubHistory {
  PlayerClubHistory({
    required this.playerId,
    required List<PlayerClubHistoryEntry> clubs,
  }) : clubs = List.unmodifiable(clubs);

  final int playerId;

  /// Preserves the backend's most-recent-first ordering.
  final List<PlayerClubHistoryEntry> clubs;
}
