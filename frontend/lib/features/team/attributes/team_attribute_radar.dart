import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

class TeamAttributeRadar extends StatelessWidget {
  const TeamAttributeRadar(
      {super.key, required this.scores, this.comparisonScores});

  final TeamAttributeScores scores;
  final TeamAttributeScores? comparisonScores;

  //   Radar chart

  // Fixed frame for the radar's scale. fl_chart derives the chart's center and
  // radius from the min/max value across ALL datasets, so without a pinned
  // range MY TEAM's polygon would rescale (and visibly change shape) every time
  // a different comparison season is picked. Anchoring the floor/ceiling keeps
  // MY TEAM identical no matter what it's compared to. Attribute values are
  // clamped to 5-95, so 0..100 gives clean headroom and aligns with tickCount.
  static const double _radarFloor = 0;
  static const double _radarCeil = 100;

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final comparisonColor = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 260,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          gridBorderData: BorderSide(color: appColors.divider, width: 1),
          radarBorderData: BorderSide(color: appColors.divider, width: 1),
          tickBorderData: BorderSide(color: appColors.divider, width: 1),
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 0),
          getTitle: (index, _) {
            final label = teamAttributeLabels[index];
            final moveOutward = label == 'Progression' || label == 'Possession';
            return RadarChartTitle(
              text: label,
              angle: 0,
              positionPercentageOffset: moveOutward ? 0.3 : null,
            );
          },
          titleTextStyle: Eyebrow.style,
          titlePositionPercentageOffset: 0.15,
          dataSets: [
            // MY TEAM — red
            RadarDataSet(
              fillColor: const Color(0xFFE8434A).withValues(alpha: 0.3),
              borderColor: const Color(0xFFE8434A),
              borderWidth: 2,
              entryRadius: 0,
              dataEntries:
                  scores.radarValues.map((v) => RadarEntry(value: v)).toList(),
            ),
            // Comparison — white outline
            if (comparisonScores != null)
              RadarDataSet(
                fillColor: comparisonColor.withValues(alpha: 0.1),
                borderColor: comparisonColor.withValues(alpha: 0.85),
                borderWidth: 2,
                entryRadius: 0,
                dataEntries: comparisonScores!.radarValues
                    .map((v) => RadarEntry(value: v))
                    .toList(),
              ),
            // Invisible anchor — pins the scale to a fixed [floor, ceil] range
            // so the visible polygons never rescale between comparisons.
            _scaleAnchorDataSet(),
          ],
        ),
      ),
    );
  }

  // Fully transparent dataset carrying one floor value and the rest at the
  // ceiling, so both minEntry and maxEntry across the chart stay constant.
  RadarDataSet _scaleAnchorDataSet() {
    final count = scores.radarValues.length;
    return RadarDataSet(
      fillColor: Colors.transparent,
      borderColor: Colors.transparent,
      borderWidth: 0,
      entryRadius: 0,
      dataEntries: List.generate(
        count,
        (i) => RadarEntry(value: i == 0 ? _radarFloor : _radarCeil),
      ),
    );
  }
}
