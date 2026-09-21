import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/player/rating_level_ring.dart';
import 'package:onetouch/models/player_indicators.dart';

class PlayerIndicatorValue extends StatelessWidget {
  const PlayerIndicatorValue({
    super.key,
    required this.score,
    required this.loading,
    required this.failed,
    required this.explanation,
    required this.onRetry,
  });

  final PlayerIndicatorScore? score;
  final bool loading;
  final bool failed;
  final String explanation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final value = loading
        ? 'Loading'
        : failed
            ? 'Unavailable'
            : score?.grade ?? '—';
    return Tooltip(
      message: explanation,
      triggerMode: TooltipTriggerMode.tap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(value, style: Heading5.style)),
          const SizedBox(width: 8),
          if (loading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (failed)
            InkResponse(
              onTap: onRetry,
              child:
                  const Icon(Icons.refresh, size: 20, semanticLabel: 'Retry'),
            )
          else if (score?.band != null)
            Semantics(
              label: score!.percentile == null
                  ? score!.grade!
                  : '${score!.percentile!.toStringAsFixed(1)} percentile',
              child: ExcludeSemantics(
                child: RatingLevelRing(
                  rating: score!.grade!,
                  levelOverride: score!.band! + 1,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
