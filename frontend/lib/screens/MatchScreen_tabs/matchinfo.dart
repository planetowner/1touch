import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/KaneRest.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/features/player/player_stat_value.dart';

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

  String? _metricValue(FixturePlayerStatMetric metric) {
    final value = playerMetricValue(metric);
    return value == '—' ? null : value;
  }

  PlayerMatchStatData? _playerMatchStats({
    required int teamId,
    required int playerId,
    required String fallbackName,
    int? fallbackJerseyNumber,
  }) {
    final playerStatistic = detail?.playerStatistics
        .where(
          (statistic) =>
              statistic.teamId == teamId && statistic.playerId == playerId,
        )
        .firstOrNull;
    final lineup = detail?.lineups
        .where(
          (entry) => entry.teamId == teamId && entry.playerId == playerId,
        )
        .firstOrNull;
    if (playerStatistic == null) return null;

    final sections = <PlayerMatchStatSection>[
      for (final category in playerStatistic.categories)
        if (category.metrics.map(_metricValue).whereType<String>().isNotEmpty)
          PlayerMatchStatSection(
            category: category.label.toUpperCase(),
            rows: [
              for (final metric in category.metrics)
                if (_metricValue(metric) case final value?)
                  PlayerMatchStatRow(label: metric.label, value: value),
            ],
          ),
    ];
    if (sections.isEmpty) return null;

    final team = teamId == fixture.homeTeamId
        ? fixtureHomeTeam(fixture, teamRepository)
        : fixtureAwayTeam(fixture, teamRepository);
    return PlayerMatchStatData(
      playerId: playerId,
      teamPrimaryColor: team.primaryColor,
      name: lineup?.playerName ?? fallbackName,
      jerseyNumber: lineup?.jerseyNumber ?? fallbackJerseyNumber,
      positions: [
        if (playerStatistic.positionGroup != null)
          playerStatistic.positionGroup!,
      ],
      club: team.name,
      nationality: null,
      playerImageUrl: lineup?.playerImage,
      sections: sections,
    );
  }

  void _openPlayerMatchStats(BuildContext context, LineupPlayer player) {
    final stats = _playerMatchStats(
      teamId: player.teamId,
      playerId: player.playerId,
      fallbackName: player.name,
      fallbackJerseyNumber: player.number,
    );
    if (stats != null) showPlayerMatchStatSheet(context, stats);
  }

  void _openSubstituteMatchStats(BuildContext context, Substitute player) {
    final stats = _playerMatchStats(
      teamId: player.teamId,
      playerId: player.playerId,
      fallbackName: player.name,
      fallbackJerseyNumber: player.jerseyNumber,
    );
    if (stats != null) showPlayerMatchStatSheet(context, stats);
  }

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
      } else if (code == 'yellowredcard') {
        add(event.playerId, LineupEventType.secondYellowCard, event.minute);
      } else if (code == 'redcard') {
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
              teamId: item.entry.teamId,
              playerId: item.entry.playerId,
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
        teamId: entry.teamId,
        playerId: entry.playerId,
        jerseyNumber: entry.jerseyNumber,
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
        teamId: teamId,
        playerId: entry.key,
        jerseyNumber: null,
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
    final homeTeam = fixtureHomeTeam(fixture, teamRepository);
    final awayTeam = fixtureAwayTeam(fixture, teamRepository);
    final comparisonColors = TeamComparisonColorResolver.resolve(
      anchorTeamName: homeTeam.name,
      anchorPrimaryFallback: Color(homeTeam.primaryColor),
      opponentTeamName: awayTeam.name,
      opponentPrimaryFallback: Color(awayTeam.primaryColor),
      background: mainPageBackground(context),
    );
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
            homeTeamName: homeTeam.displayName,
            awayTeamName: awayTeam.displayName,
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
              fixtureId: fixture.fixtureId,
            ),
            // TODO(match-info): Restore Player of the Match when the backend
            // exposes an explicit award instead of inferring one from rating.
          ],
          if (momentumValues.isNotEmpty) ...[
            const SizedBox(height: 48),
            MomentumChart(
              values: momentumValues,
              homeColor: comparisonColors.anchor,
              awayColor: comparisonColors.opponent,
            ),
          ],
          if (statBars.isNotEmpty) ...[
            const SizedBox(height: 48),
            StatBarsSection(
              bars: statBars,
              homeColor: comparisonColors.anchor,
              awayColor: comparisonColors.opponent,
            ),
          ],
          if (hasCompleteLineup) ...[
            const SizedBox(height: 48),
            LineupPitch(
              awayRows: awayLineupRows,
              homeRows: homeLineupRows,
              homeColor: comparisonColors.anchor,
              awayColor: comparisonColors.opponent,
              onPlayerTap: detail?.playerStatistics.isEmpty ?? true
                  ? null
                  : _openPlayerMatchStats,
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
            onPlayerTap: detail?.playerStatistics.isEmpty ?? true
                ? null
                : _openSubstituteMatchStats,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
