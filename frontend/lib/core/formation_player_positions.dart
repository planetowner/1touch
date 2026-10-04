import 'package:flutter/widgets.dart';
import 'package:onetouch/core/formation_layout.dart';

/// 두 화면 모두 선수 원의 중심을 공통 디자인 좌표에 맞춰요.
class FormationPlayerPositions<T> extends StatelessWidget {
  const FormationPlayerPositions({
    super.key,
    required this.players,
    required this.positionOf,
    required this.playerWidth,
    required this.playerBuilder,
    this.reverseVertical = false,
  });

  final Iterable<T> players;
  final Offset? Function(T player) positionOf;
  final double playerWidth;
  final Widget Function(T player) playerBuilder;
  final bool reverseVertical;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / FormationLayout.designSize.width;
        final scaleY =
            constraints.maxHeight / FormationLayout.designSize.height;
        // 좁은 화면에서도 이름이 옆 선수와 겹치지 않도록 표시 폭을 줄여요.
        final width = playerWidth * (scaleX < 1 ? scaleX : 1);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final player in players)
              if (positionOf(player) case final position?)
                Positioned(
                  left: position.dx * scaleX - width / 2,
                  top: (reverseVertical
                              ? FormationLayout.designSize.height - position.dy
                              : position.dy) *
                          scaleY -
                      16,
                  width: width,
                  child: playerBuilder(player),
                ),
          ],
        );
      },
    );
  }
}
