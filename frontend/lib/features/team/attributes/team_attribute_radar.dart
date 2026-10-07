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
      this.comparisonColor,
      this.balanceVerticalMargins = false});

  final TeamAttributeScores scores;
  final TeamAttributeScores? comparisonScores;
  final Color currentColor;
  final Color? comparisonColor;
  final bool balanceVerticalMargins;

  // fl_chart는 모든 데이터셋의 최솟값·최댓값으로 반지름을 정해요. 축을 0~100으로
  // 고정해야 비교 시즌이 바뀌어도 현재 팀 도형이 같은 크기로 남아요.
  // 표시 점수는 5~95로 제한하므로 양끝에 여유가 있고 눈금도 일정해요.
  static const double _radarFloor = 0;
  static const double _radarCeil = 100;
  static const double _chartHeight = 238;
  static const double _balancedChartHeight = 250;

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
      final frameHeight =
          balanceVerticalMargins ? _balancedChartHeight : _chartHeight;
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';
      final labels = <(String, double, double)>[];
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
        labels.add((title, painter.width, painter.height));
        painter.dispose();
      }

      const gap = 8.0;
      const lowerVertexHeight = 0.8090169943749475; // sin(54°)
      final topHeight = labels[0].$3;
      final bottomHeight = math.max(labels[2].$3, labels[3].$3);
      // 카드 위아래 25px 여백과 바깥 라벨 주변 20px을 남겨요.
      // 언어별 라벨 높이에 맞춰 오각형을 300px 카드 안에 넣어요.
      final radius = balanceVerticalMargins
          ? math.min(
              constraints.maxWidth * 0.4,
              (frameHeight + 10 - topHeight - bottomHeight - 2 * gap) /
                  (1 + lowerVertexHeight),
            )
          : math.min(constraints.maxWidth, frameHeight) * 0.4;
      final centerY = balanceVerticalMargins
          ? (frameHeight +
                  (1 - lowerVertexHeight) * radius +
                  topHeight -
                  bottomHeight) /
              2
          : frameHeight / 2;

      for (var index = 0; index < labels.length; index++) {
        final (title, titleWidth, titleHeight) = labels[index];

        // fl_chart와 같은 꼭짓점 좌표를 쓰되, 문구는 도형과 별도로 배치해요.
        final angle =
            2 * math.pi * index / teamAttributeLabels.length - math.pi / 2;
        final vertex = Offset(
          constraints.maxWidth / 2 + radius * math.cos(angle),
          centerY + radius * math.sin(angle),
        );
        var left = vertex.dx - titleWidth / 2;
        var top = index == 0 ? vertex.dy - titleHeight - gap : vertex.dy + gap;
        if (index == 1 || index == 4) {
          final isRight = index == 1;
          left = isRight
              ? math.min(
                  vertex.dx + gap, constraints.maxWidth - titleWidth - gap)
              : math.max(vertex.dx - titleWidth - gap, gap);
          top = vertex.dy - titleHeight / 2;
          final innerEdge = isRight ? left : left + titleWidth;
          if (isRight ? innerEdge < vertex.dx : innerEdge > vertex.dx) {
            // 좁은 카드에서 좌우 문구가 들어오면 위쪽 빗변 위로 올려 겹치지 않게 해요.
            final edgeY = centerY -
                radius +
                (innerEdge - constraints.maxWidth / 2) *
                    (1 + math.sin(angle)) /
                    math.cos(angle);
            top = math.min(top, edgeY - titleHeight - gap);
          }
        }
        titles.add(Positioned(
          left: left,
          top: top,
          width: titleWidth,
          child: Text(
            title,
            key: ValueKey('team-attribute-axis-$index'),
            style: titleStyle,
            textAlign: TextAlign.center,
            softWrap: false,
          ),
        ));
      }
      final radarChart = RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          gridBorderData: BorderSide(color: appColors.divider, width: 1),
          radarBorderData: BorderSide(color: appColors.divider, width: 1),
          tickBorderData: BorderSide(color: appColors.divider, width: 1),
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 0),
          dataSets: [
            RadarDataSet(
              fillColor: currentColor.withValues(alpha: 0.3),
              borderColor: currentColor,
              borderWidth: 2,
              entryRadius: 0,
              dataEntries:
                  scores.radarValues.map((v) => RadarEntry(value: v)).toList(),
            ),
            if (comparisonScores != null)
              RadarDataSet(
                fillColor: resolvedComparisonColor.withValues(alpha: 0.1),
                borderColor: resolvedComparisonColor.withValues(alpha: 0.85),
                borderWidth: 2,
                entryRadius: 0,
                dataEntries: comparisonScores!.radarValues
                    .map((v) => RadarEntry(value: v))
                    .toList(),
              ),
            _scaleAnchorDataSet(),
          ],
        ),
      );
      final chartSide = radius / 0.4;
      return SizedBox(
        height: frameHeight,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (balanceVerticalMargins)
              Positioned(
                left: (constraints.maxWidth - chartSide) / 2,
                top: centerY - chartSide / 2,
                width: chartSide,
                height: chartSide,
                child: radarChart,
              )
            else
              radarChart,
            ...titles,
          ],
        ),
      );
    });
  }

  // 투명 데이터셋에 축의 양끝 값을 넣어 fl_chart의 최솟값·최댓값을 고정해요.
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
