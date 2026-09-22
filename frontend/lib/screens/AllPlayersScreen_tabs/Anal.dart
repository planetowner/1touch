import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/models/player_detail.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key, this.player, this.playerId});

  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  int? _seasonId;

  @override
  void didUpdateWidget(covariant AnalysisTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _seasonId = null;
  }

  @override
  Widget build(BuildContext context) => PlayerDetailView(
        playerId: widget.id,
        seasonId: _seasonId,
        builder: (context, detail) => SingleChildScrollView(
          key: const ValueKey('player-analysis-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 144),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerSeasonSelector(
                key: ValueKey(
                    'player-analysis-season-${detail.selectedSeason?.id}'),
                detail: detail,
                onChanged: (id) => setState(() => _seasonId = id),
              ),
              const SizedBox(height: 32),
              if (detail.analysis == null)
                const Text('Select a season with league appearances')
              else
                ..._content(detail, detail.analysis!),
            ],
          ),
        ),
      );

  List<Widget> _content(PlayerDetail detail, PlayerAnalysis analysis) => [
        _topStats(detail, analysis),
        const SizedBox(height: 32),
        _influenceBlock(detail, analysis),
        const SizedBox(height: 48),
        _attributes(detail),
        const SizedBox(height: 48),
        PlayerSection(
          title: 'PERFORMANCE',
          child: PlayerPerformanceChart(points: analysis.performance),
        ),
      ];

  Widget _topStats(PlayerDetail detail, PlayerAnalysis analysis) {
    final season = detail.selectedSeason;
    return PlayerSection(
      title: 'TOP STATS',
      titleAccessory: Tooltip(
        triggerMode: TooltipTriggerMode.tap,
        message:
            '${season?.name ?? 'Current season'} ${season?.competitionName ?? ''} · ${analysis.position ?? '—'} · reference players with at least ${analysis.minimumMinutes} minutes.',
        child: const Icon(
          Icons.help_outline,
          key: ValueKey('top-stats-help-icon'),
          size: 18,
        ),
      ),
      child: PlayerSurface(
        key: const ValueKey('player-top-stats-card'),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(
                child: _topStat(index < analysis.topStats.length
                    ? analysis.topStats[index]
                    : null),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topStat(PlayerSeasonMetric? stat) {
    final percent = stat?.metric.kind == 'percentage';
    final appColors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.of(context).subtleBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat == null
                  ? '—'
                  : '${playerNumber(percent ? stat.metric.value : stat.per90)}${percent ? '%' : ''}',
              style: Heading2.style,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: Text(
            stat?.metric.label ?? 'Unavailable',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Body1.style,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              stat?.rank == null
                  ? '—'
                  : '#${stat!.rank} / ${stat.referenceCount}',
              style: Body1.style.copyWith(color: AppPalette.white),
            ),
          ),
        ),
        if (stat != null && stat.observedMatches < stat.totalMatches)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${stat.observedMatches}/${stat.totalMatches} matches',
              textAlign: TextAlign.center,
              style: Eyebrow.style.copyWith(color: appColors.mutedForeground),
            ),
          ),
      ],
    );
  }

  Widget _influenceBlock(PlayerDetail detail, PlayerAnalysis analysis) {
    final record =
        detail.competitions.isEmpty ? null : detail.competitions.first.record;
    final minutesPerGame = record == null || record.appearances == 0
        ? null
        : record.minutes / record.appearances;
    final metrics = analysis.categories.expand((item) => item.metrics);
    double metric(String code) => metrics
        .where((item) => item.metric.code == code)
        .map((item) => item.metric.value ?? 0)
        .fold(0, (sum, value) => sum + value);
    final contributions = metric('goals') + metric('assists');
    return PlayerSection(
      title: 'INFLUENCE',
      child: GridView.count(
        padding: EdgeInsets.zero,
        primary: false,
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: .75,
        children: [
          _influence('Starting Rate', analysis.startingRate, '%'),
          _influence('Win Rate', analysis.winRate, '%'),
          _influence('Minutes Played\nPer Game', minutesPerGame, ' Min.'),
          _influence('Goal\nContributions', contributions, ''),
        ],
      ),
    );
  }

  Widget _influence(String label, double? value, String suffix) =>
      PlayerSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Body1.style),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value == null
                        ? '—'
                        : playerNumber(value, decimals: suffix.isEmpty ? 0 : 1),
                    style: Heading1.style,
                  ),
                  if (value != null && suffix.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(suffix, style: Heading4.style),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _attributes(PlayerDetail detail) {
    final team = detail.profile.teamId == null
        ? null
        : teamRepository.findById(detail.profile.teamId!);
    final accent = Color(team?.primaryColor ?? 0xFFFF5C5C);
    return PlayerSection(
      title: 'ATTRIBUTES',
      trailing: const Icon(Icons.chevron_right),
      child: PlayerSurface(
        key: const ValueKey('player-attributes-card'),
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 260,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar, size: 48, color: accent),
                const SizedBox(height: 16),
                const Text('아직 준비중이에요ㅠㅠ', style: Heading5.style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerPerformanceChart extends StatelessWidget {
  const PlayerPerformanceChart({super.key, required this.points});

  final List<PlayerPerformancePoint> points;

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final valid = points.where((point) => point.rating != null).toList();
    return PlayerSurface(
      key: const ValueKey('player-performance-card'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: SizedBox(
        height: 317,
        child: valid.isEmpty
            ? const Center(child: Text('No ratings available'))
            : Row(
                children: [
                  const RotatedBox(
                    quarterTurns: 3,
                    child: Text('PERFORMANCE', style: Body2_b.style),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              minX: points.first.round.toDouble() - .5,
                              maxX: points.last.round.toDouble() + .5,
                              minY: 0,
                              maxY: 10,
                              gridData: FlGridData(
                                drawVerticalLine: false,
                                horizontalInterval: 1.25,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: appColors.divider,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: const FlTitlesData(
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (final point in points)
                                      point.rating == null
                                          ? FlSpot.nullSpot
                                          : FlSpot(point.round.toDouble(),
                                              point.rating!),
                                  ],
                                  color: const Color(0xFF5C92FF),
                                  barWidth: 2,
                                  isCurved: false,
                                  dotData: const FlDotData(show: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('ROUND', style: Body2_b.style),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
