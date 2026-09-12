import 'package:flutter/material.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/MatchInfoFeatures.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';

import '../../models/match_data.dart';
import 'match_event_view_data.dart';

class MatchInfoTab extends StatelessWidget {
  final Fixture fixture;
  final String matchStatus; // "past" | "live"
  final FixtureDetail? detail;

  MatchInfoTab({
    super.key,
    required this.fixture,
    required this.matchStatus,
    this.detail,
  });

  bool get isLive => matchStatus == 'live';

  static const _statDefinitions =
      <({String code, String label, bool isPercent})>[
    (code: 'shots-total', label: 'Shots', isPercent: false),
    (code: 'shots-on-target', label: 'Shots on Target', isPercent: false),
    (
      code: 'successful-passes-percentage',
      label: 'Pass Accuracy',
      isPercent: true,
    ),
    (code: 'fouls', label: 'Fouls', isPercent: false),
    (code: 'corners', label: 'Corners', isPercent: false),
    (code: 'offsides', label: 'Offsides', isPercent: false),
    (code: 'yellowcards', label: 'Yellow Cards', isPercent: false),
    (code: 'saves', label: 'Saves', isPercent: false),
  ];

  List<StatBarData> _statBars() {
    final valuesByCode = <String, Map<int, double>>{};
    for (final statistic in detail?.statistics ?? const <FixtureStatistic>[]) {
      valuesByCode.putIfAbsent(
              statistic.statCode, () => <int, double>{})[statistic.teamId] =
          statistic.value;
    }

    StatBarData? pairedStatistic({
      required String code,
      required String label,
      required bool isPercent,
    }) {
      final values = valuesByCode[code];
      if (values == null || values.isEmpty) return null;
      final homeValue = values[fixture.homeTeamId];
      final awayValue = values[fixture.awayTeamId];
      // Sportmonks omits zero-valued count statistics. If this statistic is
      // present for one team, a missing opponent count therefore displays 0;
      // percentages still require both sides to avoid inventing a ratio.
      if (isPercent && (homeValue == null || awayValue == null)) return null;
      return StatBarData(
        category: label,
        homePercent: homeValue ?? 0,
        awayPercent: awayValue ?? 0,
        isPercent: isPercent,
      );
    }

    final result = <StatBarData>[];
    final possession = pairedStatistic(
      code: 'ball-possession',
      label: 'Possession',
      isPercent: true,
    );
    if (possession != null) result.add(possession);

    final expectedGoals = detail?.expectedGoals;
    if (expectedGoals != null) {
      result.add(
        StatBarData(
          category: 'Expected Goals',
          homePercent: expectedGoals.homeXg,
          awayPercent: expectedGoals.awayXg,
          isPercent: false,
          fractionDigits: 2,
        ),
      );
    }

    for (final definition in _statDefinitions) {
      final bar = pairedStatistic(
        code: definition.code,
        label: definition.label,
        isPercent: definition.isPercent,
      );
      if (bar != null) result.add(bar);
    }
    return result;
  }

  List<double> _momentumValues() {
    final points = (detail?.pressure ?? const <FixturePressurePoint>[])
        .where(
          (point) =>
              point.minute >= 0 &&
              point.minute <= 90 &&
              (point.teamId == fixture.homeTeamId ||
                  point.teamId == fixture.awayTeamId),
        )
        .toList(growable: false);
    if (points.length < 2) return const [];

    final values = List<double>.filled(91, 0);
    for (final point in points) {
      final direction = point.teamId == fixture.homeTeamId ? 1 : -1;
      values[point.minute] += point.pressure * direction;
    }
    return values;
  }

  Map<int, List<LineupEvent>> _lineupEventsByPlayer() {
    final result = <int, List<LineupEvent>>{};

    void add(int? playerId, LineupEventType type, int minute) {
      if (playerId == null) return;
      result
          .putIfAbsent(playerId, () => <LineupEvent>[])
          .add(LineupEvent(type: type, minute: minute));
    }

    for (final event in detail?.events ?? const <FixtureEvent>[]) {
      final code = event.eventTypeCode;
      if (fixtureGoalEventCodes.contains(code)) {
        add(event.playerId, LineupEventType.goal, event.minute);
        if (code != 'owngoal') {
          add(event.relatedPlayerId, LineupEventType.assist, event.minute);
        }
      } else if (code == 'yellowcard') {
        add(event.playerId, LineupEventType.yellowCard, event.minute);
      } else if (fixtureRedCardEventCodes.contains(code)) {
        add(event.playerId, LineupEventType.redCard, event.minute);
      } else if (code == 'substitution') {
        add(event.playerId, LineupEventType.subIn, event.minute);
        add(event.relatedPlayerId, LineupEventType.subOut, event.minute);
      }
    }
    return result;
  }

  List<List<LineupPlayer>> _lineupRows(
    int teamId, {
    required bool reverse,
  }) {
    final eventsByPlayer = _lineupEventsByPlayer();
    final positioned = <({FixtureLineupEntry entry, int row, int slot})>[];
    for (final entry in detail?.lineups ?? const <FixtureLineupEntry>[]) {
      if (entry.teamId != teamId) continue;
      final parts = entry.formationField?.split(':');
      if (parts == null || parts.length < 2) continue;
      final row = int.tryParse(parts[0]);
      final slot = int.tryParse(parts[1]);
      if (row == null || slot == null) continue;
      positioned.add((entry: entry, row: row, slot: slot));
    }

    final grouped = <int, List<({FixtureLineupEntry entry, int slot})>>{};
    for (final item in positioned) {
      grouped
          .putIfAbsent(
        item.row,
        () => <({FixtureLineupEntry entry, int slot})>[],
      )
          .add((entry: item.entry, slot: item.slot));
    }
    final rowNumbers = grouped.keys.toList()..sort();
    final orderedRows = reverse ? rowNumbers.reversed : rowNumbers;

    return [
      for (final rowNumber in orderedRows)
        [
          for (final item in (grouped[rowNumber]!
            ..sort(
              (a, b) => a.slot.compareTo(b.slot),
            )))
            LineupPlayer(
              number: item.entry.jerseyNumber,
              name: item.entry.playerName,
              events: eventsByPlayer[item.entry.playerId] ?? const [],
            ),
        ],
    ];
  }

  List<Substitute> _substitutes(int teamId) {
    final events = detail?.events ?? const <FixtureEvent>[];
    final substitutionsByPlayer = <int, FixtureEvent>{
      for (final event in events)
        if (event.teamId == teamId &&
            event.eventTypeCode == 'substitution' &&
            event.playerId != null)
          event.playerId!: event,
    };
    final goalScorers = {
      for (final event in events)
        if (event.teamId == teamId &&
            fixtureGoalEventCodes.contains(event.eventTypeCode) &&
            event.playerId != null)
          event.playerId!,
    };
    final result = <int, Substitute>{};

    for (final entry in detail?.lineups ?? const <FixtureLineupEntry>[]) {
      final formationField = entry.formationField?.trim();
      if (entry.teamId != teamId ||
          (formationField != null && formationField.isNotEmpty)) {
        continue;
      }
      final substitution = substitutionsByPlayer[entry.playerId];
      result[entry.playerId] = Substitute(
        name: entry.playerName,
        minute: substitution?.minute,
        subIn: substitution != null,
        goal: goalScorers.contains(entry.playerId),
      );
    }
    for (final entry in substitutionsByPlayer.entries) {
      final event = entry.value;
      if (result.containsKey(entry.key) || event.playerName == null) continue;
      result[entry.key] = Substitute(
        name: event.playerName!,
        minute: event.minute,
        subIn: true,
        goal: goalScorers.contains(entry.key),
      );
    }
    return result.values.toList(growable: false);
  }

  String? _formation(int teamId) => detail?.formations
      .where((formation) => formation.teamId == teamId)
      .map((formation) => formation.formation)
      .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final homeTeam = teamRepository.findByIdOrUnknown(fixture.homeTeamId);
    final awayTeam = teamRepository.findByIdOrUnknown(fixture.awayTeamId);
    final homeScore = fixture.homeScore?.toString() ?? '#';
    final awayScore = fixture.awayScore?.toString() ?? '#';
    final coachNamesByTeam = {
      for (final coach in detail?.coaches ?? const <FixtureCoach>[])
        coach.teamId: coach.name,
    };
    final matchEvents = fixtureSummaryEventRows(
      events: detail?.events ?? const <FixtureEvent>[],
      homeTeamId: fixture.homeTeamId,
      awayTeamId: fixture.awayTeamId,
    );
    final momentumValues = _momentumValues();
    final statBars = _statBars();
    final homeLineupRows = _lineupRows(fixture.homeTeamId, reverse: true);
    final awayLineupRows = _lineupRows(fixture.awayTeamId, reverse: false);
    final hasCompleteLineup =
        homeLineupRows.isNotEmpty && awayLineupRows.isNotEmpty;
    final homeSubstitutes = _substitutes(fixture.homeTeamId);
    final awaySubstitutes = _substitutes(fixture.awayTeamId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MatchScoreHeader(
            homeLogoAsset: homeTeam.imagePath ?? '',
            awayLogoAsset: awayTeam.imagePath ?? '',
            homeTeamId: homeTeam.teamId,
            awayTeamId: awayTeam.teamId,
            homeTeamName: homeTeam.name,
            awayTeamName: awayTeam.name,
            homeScore: homeScore,
            awayScore: awayScore,
            statusLabel: isLive ? 'Live' : 'Final',
            roundLabel: fixture.roundName,
            venueLabel: detail?.venueName,
          ),
          if (matchEvents.isNotEmpty) ...[
            const SizedBox(height: 12),
            MatchEventsSection(events: matchEvents),
          ],
          if (!isLive) ...[
            const SizedBox(height: 24),
            MatchHighlights(
              imageAsset: 'assets/highlight1.png',
              homeTeamId: homeTeam.teamId,
              awayTeamId: awayTeam.teamId,
            ),
            // TODO(match-info): Restore Player of the Match when the backend
            // exposes an explicit award instead of inferring one from rating.
          ],
          if (momentumValues.isNotEmpty) ...[
            const SizedBox(height: 48),
            MomentumChart(values: momentumValues),
          ],
          if (statBars.isNotEmpty) ...[
            const SizedBox(height: 48),
            StatBarsSection(bars: statBars),
          ],
          if (hasCompleteLineup) ...[
            const SizedBox(height: 48),
            LineupPitch(
              awayRows: awayLineupRows,
              homeRows: homeLineupRows,
              homeFormation: _formation(fixture.homeTeamId),
              awayFormation: _formation(fixture.awayTeamId),
            ),
          ],
          const SizedBox(height: 48),
          SubstitutesAndCoach(
            subsA: homeSubstitutes,
            subsB: awaySubstitutes,
            coachA: coachNamesByTeam[fixture.homeTeamId] ?? '—',
            coachB: coachNamesByTeam[fixture.awayTeamId] ?? '—',
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
