import 'package:flutter/material.dart';
import 'package:onetouch/features/competition/competition_label.dart';

class TeamStandingLabel extends StatelessWidget {
  const TeamStandingLabel({
    super.key,
    required this.competitionId,
    required this.label,
    required this.style,
    required this.rankDelta,
    required this.risingIcon,
    required this.fallingIcon,
    this.risingValueStyle,
    this.fallingValueStyle,
    this.textKey,
    this.movementKey,
    this.movementValueKey,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final int? competitionId;
  final String label;
  final TextStyle style;
  final int? rankDelta;
  // 화면마다 다른 아이콘과 색상만 받고, 변동 표시 조건은 여기서 관리해요.
  final Widget risingIcon;
  final Widget fallingIcon;
  final TextStyle? risingValueStyle;
  final TextStyle? fallingValueStyle;
  final Key? textKey;
  final Key? movementKey;
  final Key? movementValueKey;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Flexible(
            child: CompetitionLabel(
              competitionId: competitionId,
              label: label,
              style: style,
              textKey: textKey,
              mainAxisAlignment: MainAxisAlignment.start,
            ),
          ),
          if (rankDelta case final int delta when delta != 0)
            Row(
              key: movementKey,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: crossAxisAlignment,
              children: [
                delta > 0 ? risingIcon : fallingIcon,
                Text(
                  '${delta.abs()}',
                  key: movementValueKey,
                  style: (delta > 0 ? risingValueStyle : fallingValueStyle) ??
                      style,
                ),
              ],
            ),
        ],
      );
}
