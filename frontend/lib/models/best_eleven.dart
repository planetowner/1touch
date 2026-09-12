// id | team_id | season_id | formation | slot_key | slot_index
// player_id | player_name | player_image
// position_name | detailed_position_name | starts | total_minutes | updated_at

class BestElevenPlayer {
  final int id;
  final int teamId;
  final int seasonId;
  final String formation;   // e.g. '4-3-3'
  final String slotKey;     // e.g. '2:1' (row:col) — used to build pitch layout
  final int slotIndex;      // 0-10, GK=0 … ST=10

  final int playerId;
  final String playerName;
  final String playerImage;

  final String positionName;          // 'Goalkeeper' | 'Defender' | 'Midfielder' | 'Attacker'
  final String detailedPositionName;  // 'Centre Back', 'Right Wing', etc.
  final int starts;
  final int totalMinutes;

  final String updatedAt;

  const BestElevenPlayer({
    required this.id,
    required this.teamId,
    required this.seasonId,
    required this.formation,
    required this.slotKey,
    required this.slotIndex,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.positionName,
    required this.detailedPositionName,
    required this.starts,
    required this.totalMinutes,
    required this.updatedAt,
  });

  factory BestElevenPlayer.fromJson(Map<String, dynamic> json) {
    return BestElevenPlayer(
      id:                   json['id']                     as int,
      teamId:               json['team_id']                as int,
      seasonId:             json['season_id']              as int,
      formation:            json['formation']              as String,
      slotKey:              json['slot_key']               as String,
      slotIndex:            json['slot_index']             as int,
      playerId:             json['player_id']              as int,
      playerName:           json['player_name']            as String,
      playerImage:          json['player_image']           as String,
      positionName:         json['position_name']          as String,
      detailedPositionName: json['detailed_position_name'] as String,
      starts:               json['starts']                 as int,
      totalMinutes:         json['total_minutes']          as int,
      updatedAt:            json['updated_at']             as String,
    );
  }
}
