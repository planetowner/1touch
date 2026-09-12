import 'package:onetouch/models/fixture_detail.dart';

const fixtureGoalEventCodes = {'goal', 'owngoal', 'penalty'};
const fixtureRedCardEventCodes = {'redcard', 'yellowredcard'};

List<Map<String, dynamic>> fixtureSummaryEventRows({
  required Iterable<FixtureEvent> events,
  required int homeTeamId,
  required int awayTeamId,
}) {
  final source = List<FixtureEvent>.of(events)..sort(_compareEvents);
  final result = <Map<String, dynamic>>[];

  for (final event in source) {
    final playerName = event.playerName?.trim();
    final type = _summaryEventType(event.eventTypeCode);
    final team = event.teamId == homeTeamId
        ? 'home'
        : event.teamId == awayTeamId
            ? 'away'
            : null;
    if (playerName == null ||
        playerName.isEmpty ||
        type == null ||
        team == null) {
      continue;
    }
    result.add({
      'player': playerName,
      'minute': _minuteLabel(event),
      'team': team,
      'type': type,
    });
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

String? _summaryEventType(String code) {
  if (fixtureGoalEventCodes.contains(code)) return 'goal';
  if (fixtureRedCardEventCodes.contains(code)) return 'redCard';
  return null;
}
