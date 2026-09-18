part of 'match_info_features.dart';

enum LineupEventType {
  yellowCard,
  secondYellowCard,
  redCard,
  goal,
  subIn,
  subOut,
  assist,
  injury
}

class LineupEvent {
  final LineupEventType type;
  final int? minute;
  const LineupEvent({required this.type, this.minute});
}

class LineupPlayer {
  final int teamId;
  final int playerId;
  final int? number;
  final String name;
  final List<LineupEvent> events;
  const LineupPlayer({
    required this.teamId,
    required this.playerId,
    required this.number,
    required this.name,
    this.events = const [],
  });
}
