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

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final resolvedComparisonColor =
        comparisonColor ?? Theme.of(context).colorScheme.onSurface;
    // Text가 상속받는 자간도 함께 재야 문구 끝이 잘리지 않아요.
    final titleStyle = DefaultTextStyle.of(context)
        .style
        .merge(Eyebrow.style)
        .copyWith(height: 1.3);
    return LayoutBuilder(builder: (context, constraints) {
      final titles = <Widget>[];
      // 축 문구가 길어져도 기존 차트 크기는 유지해요.
      final radius = math.min(constraints.maxWidth, _chartHeight) * 0.4;
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';
      for (var index = 0; index < teamAttributeLabels.length; index++) {
        var text = tr(context, teamAttributeLabels[index]);
        // 영어 복합 명칭은 항상 나누고, &는 앞 단어와 같은 줄에 둬요.
        if (isEnglish) {
          text = text.contains(' & ')
              ? text.replaceAll(' & ', ' &\n')
              : text.replaceAll(' ', '\n');
        }
        final painter = TextPainter(
          text: TextSpan(text: text, style: titleStyle),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
            maxWidth: isEnglish ? double.infinity : constraints.maxWidth / 3,
          );

        // 긴 복합 명칭은 구분점 뒤에서 먼저 나눠 단어가 중간에 잘리지 않게 해요.
        if (painter.computeLineMetrics().length > 1 && text.contains('・')) {
          text = text.replaceAll('・', '・\n');
          painter
            ..text = TextSpan(text: text, style: titleStyle)
            ..layout(maxWidth: constraints.maxWidth / 3);
        }

        // 문구 위치를 재기 전에 실제 표시할 줄바꿈을 확정해요.
        final title = painter.computeLineMetrics().map((line) {
          final position =
              painter.getPositionForOffset(Offset(0, line.baseline));
          final range = painter.getLineBoundary(position);
          return text.substring(range.start, range.end).trim();
        }).join('\n');
        painter
          ..text = TextSpan(text: title, style: titleStyle)
          ..layout();

        // fl_chart와 같은 꼭짓점 좌표를 쓰되, 문구는 도형과 별도로 배치해요.
        final angle =
            2 * math.pi * index / teamAttributeLabels.length - math.pi / 2;
        final vertex = Offset(
          constraints.maxWidth / 2 + radius * math.cos(angle),
          _chartHeight / 2 + radius * math.sin(angle),
        );
        const gap = 8.0;
        var left = vertex.dx - painter.width / 2;
        var top =
            index == 0 ? vertex.dy - painter.height - gap : vertex.dy + gap;
        if (index == 1 || index == 4) {
          final isRight = index == 1;
          left = isRight
              ? math.min(
                  vertex.dx + gap, constraints.maxWidth - painter.width - gap)
              : math.max(vertex.dx - painter.width - gap, gap);
          top = vertex.dy - painter.height / 2;
          final innerEdge = isRight ? left : left + painter.width;
          if (isRight ? innerEdge < vertex.dx : innerEdge > vertex.dx) {
            // 좁은 카드에서 좌우 문구가 들어오면 위쪽 빗변 위로 올려 겹치지 않게 해요.
            final edgeY = _chartHeight / 2 -
                radius +
                (innerEdge - constraints.maxWidth / 2) *
                    (1 + math.sin(angle)) /
                    math.cos(angle);
            top = math.min(top, edgeY - painter.height - gap);
          }
        }
        titles.add(Positioned(
          left: left,
          top: top,
          width: painter.width,
          child: Text(
            title,
            key: ValueKey('team-attribute-axis-$index'),
            style: titleStyle,
            textAlign: TextAlign.center,
            softWrap: false,
          ),
        ));
        painter.dispose();
      }
      return SizedBox(
        height: _chartHeight,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 4,
                gridBorderData: BorderSide(color: appColors.divider, width: 1),
                radarBorderData: BorderSide(color: appColors.divider, width: 1),
                tickBorderData: BorderSide(color: appColors.divider, width: 1),
                ticksTextStyle:
                    const TextStyle(color: Colors.transparent, fontSize: 0),
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
            ...titles,
          ],
        ),
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
