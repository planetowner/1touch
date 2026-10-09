import 'package:flutter/foundation.dart';

/// 즐겨찾기 목록의 선수 정보와 현재 소속팀·등번호예요.
@immutable
class FollowingPlayer {
  const FollowingPlayer({
    required this.playerId,
    required this.name,
    required this.imagePath,
    this.jerseyNumber,
    this.teamId,
    this.teamName,
  });

  final int playerId;
  final String name;
  final String? imagePath;
  final int? jerseyNumber;
  final int? teamId;
  final String? teamName;
}
