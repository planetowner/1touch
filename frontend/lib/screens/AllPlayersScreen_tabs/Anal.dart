import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
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
    if (oldWidget.id != widget.id) {
      _seasonId = null;
    }
  }

  @override
  Widget build(BuildContext context) => PlayerDetailView(
      playerId: widget.id,
      seasonId: _seasonId,
      builder: (context, detail) => SingleChildScrollView(
          key: const ValueKey('player-analysis-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 144),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlayerSeasonSelector(
                key: ValueKey(
                    'player-analysis-season-${detail.selectedSeason?.id}'),
                detail: detail,
                onChanged: (id) => setState(() => _seasonId = id)),
            const SizedBox(height: 32),
            if (detail.analysis == null)
              const Text('Select a season with league appearances')
            else
              ..._content(detail.analysis!, detail.selectedSeason!),
          ])));

  List<Widget> _content(PlayerAnalysis analysis, PlayerDetailSeason season) => [
        PlayerSection(
            title: 'TOP STATS',
            trailing: Tooltip(
                triggerMode: TooltipTriggerMode.tap,
                message:
                    '${season.name} ${season.competitionName} · ${analysis.position ?? '—'} · reference players with at least ${analysis.minimumMinutes} minutes. Counts per 90; percentages from total successes / attempts. Missing records are not ranked.',
                child: const Icon(Icons.help_outline, size: 18)),
            child: PlayerSurface(
                key: const ValueKey('player-top-stats-card'),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _topStat(i < analysis.topStats.length
                                    ? analysis.topStats[i]
                                    : null)))
                    ]))),
        const SizedBox(height: 32),
        PlayerSection(
            title: 'INFLUENCE',
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _influence('Starting Rate', analysis.startingRate,
                      '${analysis.starts} starts / ${analysis.teamMatches} team matches')),
              const SizedBox(width: 16),
              Expanded(
                  child: _influence('Win Rate', analysis.winRate,
                      'Wins in player appearances')),
            ])),
        const SizedBox(height: 40),
        PlayerStatCategories(categories: analysis.categories),
        PlayerSection(
            title: 'PERFORMANCE',
            child: PlayerPerformanceChart(points: analysis.performance)),
      ];
  Widget _topStat(PlayerSeasonMetric? stat) {
    final percent = stat?.metric.kind == 'percentage';
    return Column(children: [
      Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: AppColors.of(context).subtleBackground,
              borderRadius: BorderRadius.circular(8)),
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                  stat == null
                      ? '—'
                      : '${playerNumber(percent ? stat.metric.value : stat.per90)}${percent ? '%' : ''}',
                  style: Heading3.style))),
      const SizedBox(height: 8),
      Text(stat?.metric.label ?? 'Unavailable',
          textAlign: TextAlign.center, style: Body2.style),
      Text(percent ? 'Success rate' : 'per 90', style: Eyebrow.style),
      const SizedBox(height: 4),
      Text(stat == null ? '—' : '#${stat.rank} / ${stat.referenceCount}',
          style: Body2_b.style),
    ]);
  }

  Widget _influence(String label, double? value, String description) =>
      PlayerSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Body1.style),
        const SizedBox(height: 24),
        FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
                value == null ? '—' : '${playerNumber(value, decimals: 1)}%',
                style: Heading2.style)),
        const SizedBox(height: 8),
        Text(description, style: Eyebrow.style),
      ]));
}

class PlayerPerformanceChart extends StatelessWidget {
  const PlayerPerformanceChart({super.key, required this.points});
  final List<PlayerPerformancePoint> points;
  @override
  Widget build(BuildContext context) {
    final valid = points.where((p) => p.rating != null).toList();
    return PlayerSurface(
        key: const ValueKey('player-performance-card'),
        child: SizedBox(
            height: 300,
            child: valid.isEmpty
                ? const Center(child: Text('No ratings available'))
                : LineChart(LineChartData(
                    minX: points.first.round.toDouble() - 0.5,
                    maxX: points.last.round.toDouble() + 0.5,
                    minY: 0,
                    maxY: 10,
                    gridData: const FlGridData(
                        drawVerticalLine: false, horizontalInterval: 2),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            axisNameWidget: Text('ROUND'),
                            sideTitles:
                                SideTitles(showTitles: true, reservedSize: 24)),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 2))),
                    lineBarsData: [
                      LineChartBarData(
                          spots: [
                            for (final p in points)
                              p.rating == null
                                  ? FlSpot.nullSpot
                                  : FlSpot(p.round.toDouble(), p.rating!)
                          ],
                          isCurved: false,
                          color: const Color(0xFF5C92FF),
                          barWidth: 2,
                          dotData: const FlDotData(show: true))
                    ],
                    lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (spots) => spots
                                .map((s) => LineTooltipItem(
                                    'Round ${s.x.toInt()} · ${s.y.toStringAsFixed(1)}',
                                    const TextStyle(color: Colors.white)))
                                .toList())),
                  ))));
  }
}
