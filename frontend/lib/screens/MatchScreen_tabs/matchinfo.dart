import 'package:flutter/material.dart';
import 'package:onetouch/core/formation_layout.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/kane_rest.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/features/match_info/match_status_label.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/features/player/player_stat_value.dart';

import '../../models/match_data.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/fixture_labels.dart';

class MatchInfoTab extends StatelessWidget {
  final Fixture fixture;
  final FixtureDetail? detail;

  MatchInfoTab({
    super.key,
    required this.fixture,
    this.detail,
  });

  bool get isLive => fixture.status == FixtureStatus.live;

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
            // 번역 키를 보존하고 대문자 표시는 시트에서 처리해요.
            category: category.label,
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
      teamId: teamId,
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

  // 경기 정보의 통계 순서는 라이브·종료 경기에서 같은 목록을 사용해요.
  static const _statDefinitions =
      <({String code, String label, bool isPercent})>[
    (code: 'ball-possession', label: 'Ball Possession', isPercent: true),
    (code: 'passes', label: 'Passes', isPercent: false),
    (
      code: 'successful-passes-percentage',
      label: 'Pass Accuracy',
      isPercent: true,
    ),
    (code: 'shots-total', label: 'Shots', isPercent: false),
    (code: 'shots-on-target', label: 'Shots on Target', isPercent: false),
    (code: 'corners', label: 'Corners', isPercent: false),
    (code: 'offsides', label: 'Offsides', isPercent: false),
    (code: 'saves', label: 'Saves', isPercent: false),
    (code: 'fouls', label: 'Fouls', isPercent: false),
    (code: 'yellowcards', label: 'Yellow Cards', isPercent: false),
    (code: 'redcards', label: 'Red Cards', isPercent: false),
  ];

  List<StatBarData> _statBars() {
    final valuesByCode = <String, Map<int, double>>{};
    for (final statistic in detail?.statistics ?? const <FixtureStatistic>[]) {
      valuesByCode.putIfAbsent(
              statistic.statCode, () => <int, double>{})[statistic.teamId] =
          statistic.value;
    }

    // 라이브 응답에서 생략된 0도 표시해 경기 중 통계 항목이 사라지지 않게 해요.
    // 상세 응답을 받기 전에는 아직 확인하지 못한 값을 0으로 표시하지 않아요.
    final showLiveZeros = isLive && detail != null;
    final result = <StatBarData>[];
    for (final definition in _statDefinitions) {
      final values = valuesByCode[definition.code];
      final homeValue = values?[fixture.homeTeamId];
      final awayValue = values?[fixture.awayTeamId];
      if (!showLiveZeros) {
        if (homeValue == null && awayValue == null) continue;
        if (definition.isPercent && (homeValue == null || awayValue == null)) {
          continue;
        }
      }
      result.add(StatBarData(
        category: definition.label,
        homePercent: homeValue ?? 0,
        awayPercent: awayValue ?? 0,
        isPercent: definition.isPercent,
      ));
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
    final formation = _formation(teamId);
    final layout =
        formation == null ? null : FormationLayout.forFormation(formation);
    final positioned = <({FixtureLineupEntry entry, int row, int slot})>[];
    for (final entry in detail?.lineups ?? const <FixtureLineupEntry>[]) {
      if (entry.teamId != teamId) continue;
      final field = entry.formationField;
      if (field == null) continue;
      final parts = formationLayoutSlotKey(formation, field).split(':');
      if (parts.length < 2) continue;
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

    // 공급자 좌표는 홈이 오른쪽부터, 원정이 왼쪽부터예요.
    // 홈 골키퍼는 아래, 원정 골키퍼는 위에 두므로 두 팀 모두 열을 역순으로 그려요.
    return [
      for (final rowNumber in orderedRows)
        [
          for (final item in (grouped[rowNumber]!
            ..sort(
              (a, b) => b.slot.compareTo(a.slot),
            )))
            LineupPlayer(
              teamId: item.entry.teamId,
              playerId: item.entry.playerId,
              number: item.entry.jerseyNumber,
              name: item.entry.playerName,
              events: eventsByPlayer[item.entry.playerId] ?? const [],
              formationPosition: layout?.positionForSlot(
                '$rowNumber:${item.slot}',
                reverseColumns: true,
              ),
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
        coach.teamId: coachNameLabel(context, coach.coachId, coach.name),
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
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MatchScoreHeader(
            homeLogoAsset: homeTeam.imagePath ?? '',
            awayLogoAsset: awayTeam.imagePath ?? '',
            homeTeamId: homeTeam.teamId,
            awayTeamId: awayTeam.teamId,
            homeTeamName: teamNameLabel(
                context, homeTeam.teamId, homeTeam.displayName,
                short: true),
            awayTeamName: teamNameLabel(
                context, awayTeam.teamId, awayTeam.displayName,
                short: true),
            homeScore: homeScore,
            awayScore: awayScore,
            status: MatchStatusLabel(fixture: fixture, clock: detail?.clock),
            roundLabel: fixtureCompetitionLabel(context, fixture) ??
                fixtureRoundLabel(fixture,
                    locale: Localizations.localeOf(context)),
          ),
          if (matchEvents.isNotEmpty) MatchEventsSection(events: matchEvents),
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
              animate: fixture.status == FixtureStatus.past,
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
            ),
          ],
          const SizedBox(height: 48),
          SubstitutesAndCoach(
            key: ValueKey('match-substitutes-${fixture.fixtureId}'),
            subsA: homeSubstitutes,
            subsB: awaySubstitutes,
            coachA: coachNamesByTeam[fixture.homeTeamId] ?? '—',
            coachB: coachNamesByTeam[fixture.awayTeamId] ?? '—',
            homeCode: homeTeam.shortCode?.trim().isNotEmpty == true
                ? homeTeam.shortCode!
                : teamNameLabel(context, homeTeam.teamId, homeTeam.name,
                    short: true),
            awayCode: awayTeam.shortCode?.trim().isNotEmpty == true
                ? awayTeam.shortCode!
                : teamNameLabel(context, awayTeam.teamId, awayTeam.name,
                    short: true),
            onPlayerTap: detail?.playerStatistics.isEmpty ?? true
                ? null
                : _openSubstituteMatchStats,
          ),
        ],
      ),
    );
  }
}
