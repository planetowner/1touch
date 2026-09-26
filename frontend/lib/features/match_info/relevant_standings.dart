import 'dart:math' as math;

import 'package:onetouch/models/standing.dart';

typedef RelevantStandingWindow = ({
  List<Standing> standings,
  int dividerIndex,
});

/// Selects at most six standings rows around the two teams in a fixture.
///
/// Nearby teams share one continuous six-row window. Teams more than five
/// places apart receive a three-row neighborhood each, separated in the UI.
RelevantStandingWindow selectRelevantMatchStandings(
  List<Standing> standings, {
  required int homeTeamId,
  required int awayTeamId,
}) {
  final sorted = standings.toList()
    ..sort((a, b) => a.position.compareTo(b.position));
  const visibleCount = 6;

  if (sorted.length <= visibleCount) {
    return (standings: sorted, dividerIndex: -1);
  }

  final homeIndex = sorted.indexWhere((row) => row.teamId == homeTeamId);
  final awayIndex = sorted.indexWhere((row) => row.teamId == awayTeamId);
  final found = [homeIndex, awayIndex].where((index) => index >= 0).toList();

  if (found.isEmpty) {
    return (
      standings: sorted.take(visibleCount).toList(),
      dividerIndex: -1,
    );
  }

  if (found.length == 1) {
    final start = _centeredWindowStart(
      index: found.single,
      count: visibleCount,
      total: sorted.length,
    );
    return (
      standings: sorted.sublist(start, start + visibleCount),
      dividerIndex: -1,
    );
  }

  final lowerIndex = math.min(homeIndex, awayIndex);
  final upperIndex = math.max(homeIndex, awayIndex);
  if (upperIndex - lowerIndex <= visibleCount - 1) {
    final minimumStart = math.max(0, upperIndex - (visibleCount - 1));
    final maximumStart = math.min(lowerIndex, sorted.length - visibleCount);
    final preferredStart =
        ((lowerIndex + upperIndex - (visibleCount - 1)) / 2).round();
    final start = preferredStart.clamp(minimumStart, maximumStart);
    return (
      standings: sorted.sublist(start, start + visibleCount),
      dividerIndex: -1,
    );
  }

  const neighborhoodSize = 3;
  final firstStart = _centeredWindowStart(
    index: lowerIndex,
    count: neighborhoodSize,
    total: sorted.length,
  );
  final secondStart = _centeredWindowStart(
    index: upperIndex,
    count: neighborhoodSize,
    total: sorted.length,
  );
  return (
    standings: [
      ...sorted.sublist(firstStart, firstStart + neighborhoodSize),
      ...sorted.sublist(secondStart, secondStart + neighborhoodSize),
    ],
    dividerIndex: neighborhoodSize,
  );
}

int _centeredWindowStart({
  required int index,
  required int count,
  required int total,
}) {
  final preferredStart = index - ((count - 1) ~/ 2);
  return preferredStart.clamp(0, total - count);
}
