import 'package:flutter/material.dart';
import 'package:onetouch/models/player.dart';

class PlayerImage extends StatelessWidget {
  final Player player;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const PlayerImage({
    super.key,
    required this.player,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: player.teamColor.first.withValues(alpha: 0.22),
      child: Center(
        child: Text(
          player.fullName
              .split(' ')
              .where((part) => part.isNotEmpty)
              .map((part) => part[0])
              .take(2)
              .join(),
          style: TextStyle(
            color: player.teamColor.first,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final image = player.imageAsset == null
        ? fallback
        : Image.asset(
            player.imageAsset!,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback,
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
