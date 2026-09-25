import 'package:flutter/foundation.dart';

@immutable
class TeamPlayerInjury {
  const TeamPlayerInjury({
    required this.sidelineId,
    required this.typeId,
    required this.typeName,
    this.startDate,
    this.endDate,
  });

  final int sidelineId;
  final int typeId;
  final String typeName;

  /// 공급자가 제공한 부상 시작일과 종료일이에요.
  /// 종료일까지는 복귀 예정 시점을 표시하고, 지난 부상은 화면에서 제외해요.
  final DateTime? startDate;
  final DateTime? endDate;

  int? daysUntilReturn(DateTime today) {
    final end = endDate;
    if (end == null) return null;
    // 종료일은 시간대가 없는 날짜예요. 시차와 서머타임으로 하루가 달라지지 않게 해요.
    return DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }
}

@immutable
class InjuredTeamPlayer {
  InjuredTeamPlayer({
    required this.playerId,
    required this.playerName,
    this.playerImage,
    this.jerseyNumber,
    required List<TeamPlayerInjury> injuries,
  }) : injuries = List.unmodifiable(injuries);

  final int playerId;
  final String playerName;
  final String? playerImage;
  final int? jerseyNumber;
  final List<TeamPlayerInjury> injuries;
}

@immutable
class TeamInjuryReport {
  TeamInjuryReport({
    required this.teamId,
    required this.seasonId,
    required List<InjuredTeamPlayer> players,
  }) : players = List.unmodifiable(players);

  final int teamId;
  final int seasonId;
  final List<InjuredTeamPlayer> players;
}
