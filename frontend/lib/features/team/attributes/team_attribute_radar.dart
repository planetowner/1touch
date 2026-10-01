import 'dart:math' as math;

import 'package:onetouch/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

class TeamAttributeRadar extends StatelessWidget {
  const TeamAttributeRadar(
      {super.key,
      required this.scores,
      this.comparisonScores,
      this.currentColor = const Color(0xFFE8434A),
      this.comparisonColor});

  final TeamAttributeScores scores;
  final TeamAttributeScores? comparisonScores;
  final Color currentColor;
  final Color? comparisonColor;

  //   Radar chart

  // Fixed frame for the radar's scale. fl_chart derives the chart's center and
  // radius from the min/max value across ALL datasets, so without a pinned
  // range MY TEAM's polygon would rescale (and visibly change shape) every time
  // a different comparison season is picked. Anchoring the floor/ceiling keeps
  // MY TEAM identical no matter what it's compared to. Attribute values are
  // clamped to 5-95, so 0..100 gives clean headroom and aligns with tickCount.
  static const double _radarFloor = 0;
  static const double _radarCeil = 100;
  static const double _chartHeight = 238;

  // 좌우 축의 여백은 번역 문구가 아니라 고정된 축 위치로 정해요.
  static double _titleOffset(int index) =>
      index == 1 || index == 4 ? 0.3 : 0.15;

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final resolvedComparisonColor =
        comparisonColor ?? Theme.of(context).colorScheme.onSurface;
    final titleStyle = Eyebrow.style.copyWith(height: 1.3);
    return LayoutBuilder(builder: (context, constraints) {
      final titles = <String>[];
      var radius = math.min(constraints.maxWidth, _chartHeight) * 0.4;
      for (var index = 0; index < teamAttributeLabels.length; index++) {
        var text = tr(context, teamAttributeLabels[index]);
        final painter = TextPainter(
          text: TextSpan(text: text, style: titleStyle),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth / 3);

        // 긴 복합 명칭은 구분점 뒤에서 먼저 나눠 단어가 중간에 잘리지 않게 해요.
        if (painter.computeLineMetrics().length > 1 && text.contains('・')) {
          text = text.replaceAll('・', '・\n');
          painter
            ..text = TextSpan(text: text, style: titleStyle)
            ..layout(maxWidth: constraints.maxWidth / 3);
        }

        // fl_chart는 축 문구를 자동으로 줄바꿈하지 않아 실제 글자 폭으로 줄을 나눠요.
        final title = painter.computeLineMetrics().map((line) {
          final position =
              painter.getPositionForOffset(Offset(0, line.baseline));
          final range = painter.getLineBoundary(position);
          return text.substring(range.start, range.end).trim();
        }).join('\n');
        titles.add(title);
        painter
          ..text = TextSpan(text: title, style: titleStyle)
          ..layout();

        // 라이브러리의 축 위치 계산에 문구 크기를 반영해 카드 안에 들어오게 해요.
        final angle =
            2 * math.pi * index / teamAttributeLabels.length - math.pi / 2;
        var distance =
            (_chartHeight / 2 - painter.height / 2 - 8) / math.sin(angle).abs();
        if (index != 0) {
          distance = math.min(
              distance,
              (constraints.maxWidth / 2 - painter.width / 2 - 8) /
                  math.cos(angle).abs());
        }
        radius = math.min(radius,
            (distance - painter.height / 2) / (1 + _titleOffset(index)));
        painter.dispose();
      }
      return SizedBox(
        height: _chartHeight,
        child: Center(
            child: SizedBox(
          // fl_chart의 반지름은 캔버스 짧은 변의 40%예요.
          width: radius / 0.4,
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
                return RadarChartTitle(
                  text: titles[index],
                  angle: 0,
                  positionPercentageOffset: _titleOffset(index),
                );
              },
              titleTextStyle: titleStyle,
              titlePositionPercentageOffset: 0.15,
              dataSets: [
                // MY TEAM — the selected team's primary color.
                RadarDataSet(
                  fillColor: currentColor.withValues(alpha: 0.3),
                  borderColor: currentColor,
                  borderWidth: 2,
                  entryRadius: 0,
                  dataEntries: scores.radarValues
                      .map((v) => RadarEntry(value: v))
                      .toList(),
                ),
                // Comparison — white outline
                if (comparisonScores != null)
                  RadarDataSet(
                    fillColor: resolvedComparisonColor.withValues(alpha: 0.1),
                    borderColor:
                        resolvedComparisonColor.withValues(alpha: 0.85),
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
        )),
      );
    });
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
