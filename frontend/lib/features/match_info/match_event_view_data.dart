import 'package:onetouch/models/fixture_detail.dart';

enum MatchEventSide { home, away }

enum MatchSummaryEventType { goal, redCard }

typedef MatchSummaryEvent = ({
  int? playerId,
  String player,
  String minute,
  MatchEventSide side,
  MatchSummaryEventType type,
});

const fixtureGoalEventCodes = {'goal', 'owngoal', 'penalty'};
const fixtureRedCardEventCodes = {'redcard', 'yellowredcard'};

List<MatchSummaryEvent> fixtureSummaryEventRows({
  required Iterable<FixtureEvent> events,
  required int homeTeamId,
  required int awayTeamId,
}) {
  final source = List<FixtureEvent>.of(events)..sort(_compareEvents);
  final result = <MatchSummaryEvent>[];

  for (final event in source) {
    final playerName = event.playerName?.trim();
    final type = _summaryEventType(event.eventTypeCode);
    final side = event.teamId == homeTeamId
        ? MatchEventSide.home
        : event.teamId == awayTeamId
            ? MatchEventSide.away
            : null;
    if (playerName == null ||
        playerName.isEmpty ||
        type == null ||
        side == null) {
      continue;
    }
    result.add((
      playerId: event.playerId,
      player: playerName,
      minute: _minuteLabel(event),
      side: side,
      type: type,
    ));
  }
  return result;
}

int _compareEvents(FixtureEvent a, FixtureEvent b) {
  // The 1Touch response does not currently expose Sportmonks `sort_order`,
  // so minute, added time, and event ID provide a deterministic fallback.
  final minute = a.minute.compareTo(b.minute);
  if (minute != 0) return minute;
  final extraMinute = (a.extraMinute ?? 0).compareTo(b.extraMinute ?? 0);
  return extraMinute != 0 ? extraMinute : a.eventId.compareTo(b.eventId);
}

String _minuteLabel(FixtureEvent event) {
  final extraMinute = event.extraMinute;
  return extraMinute == null || extraMinute == 0
      ? "${event.minute}'"
      : "${event.minute}+$extraMinute'";
}

MatchSummaryEventType? _summaryEventType(String code) {
  if (fixtureGoalEventCodes.contains(code)) {
    return MatchSummaryEventType.goal;
  }
  if (fixtureRedCardEventCodes.contains(code)) {
    return MatchSummaryEventType.redCard;
  }
  return null;
}
