import 'package:flutter/material.dart';

class Player {
  final String id;
  final String fullName;
  final String teamName;
  final List<Color> teamColor;

  Player({
    required this.id,
    required this.fullName,
    required this.teamName,
    required this.teamColor,
  });
}

final List<Player> allPlayers = [
  Player(
    id: 'son',
    fullName: 'Heungmin Son',
    teamName: 'Tottenham Hotspur',
    teamColor: [const Color(0x665C92FF), const Color(0x005C92FF)],
  ),
  // Add more if needed
];

Player getPlayerById(String id) {
  return allPlayers.firstWhere(
        (p) => p.id == id,
    orElse: () => Player(
      id: 'unknown',
      fullName: 'Unknown Player',
      teamName: 'Unknown',
      teamColor: [Colors.grey, Colors.grey],
    ),
  );
}


class RealPlayer {
  /// The squad‐record ID (e.g. "1802109142")
  final String squadId;

  /// The player’s unique ID (e.g. 3354)
  final int id;

  /// Display name (e.g. “Kalvin Phillips”)
  final String displayName;

  final String firstName;
  final String lastName;

  /// URL to head-shot PNG
  final String imagePath;

  final DateTime dateOfBirth;
  final int height;
  final int? weight;

  final int nationalityId;
  final int positionId;

  /// From the outer object
  final int? jerseyNumber;

  RealPlayer({
    required this.squadId,
    required this.id,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.imagePath,
    required this.dateOfBirth,
    required this.height,
    this.weight,
    required this.nationalityId,
    required this.positionId,
    this.jerseyNumber,
  });

  /// Creates a Player from one entry of your `"squads"` array.
  factory RealPlayer.fromSquadJson(Map<String, dynamic> squadJson) {
    final p = squadJson['players'] as Map<String, dynamic>;
    return RealPlayer(
      squadId: squadJson['id'] as String,
      id: p['id'] as int,
      displayName: p['display_name'] as String,
      firstName: p['firstname'] as String,
      lastName: p['lastname'] as String,
      imagePath: p['image_path'] as String,
      dateOfBirth: DateTime.parse(p['date_of_birth'] as String),
      height: p['height'] as int,
      weight: p['weight'] as int?,
      nationalityId: p['nationality_id'] as int,
      positionId: p['position_id'] as int,
      jerseyNumber: squadJson['jersey_number'] as int?,
    );
  }
}