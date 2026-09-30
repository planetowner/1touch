import 'package:flutter/material.dart';
import 'package:onetouch/features/team/squad/squad_player_presentation.dart';

/// Uses the same one-or-two-line name rule as the squad cards.
class PlayerWatchName extends StatelessWidget {
  const PlayerWatchName({super.key, required this.name, required this.style});

  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final normalizedName = normalizeSquadPlayerName(name);
    return LayoutBuilder(builder: (context, constraints) {
      final singleLinePainter = TextPainter(
        text: TextSpan(text: normalizedName, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fitsOnOneLine = singleLinePainter.width <= constraints.maxWidth;
      return Text(
        fitsOnOneLine ? normalizedName : twoLineSquadPlayerName(normalizedName),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    });
  }
}
