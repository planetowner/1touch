part of 'match_info_features.dart';

/// One event icon design shared by the summary, pitch, and substitutes.
class MatchEventIcon extends StatelessWidget {
  const MatchEventIcon({
    super.key,
    required this.type,
    this.size = 16,
    this.outlined = false,
    this.substituteCardStyle = false,
  });

  final LineupEventType type;
  final double size;
  final bool outlined;
  final bool substituteCardStyle;

  @override
  Widget build(BuildContext context) => _buildIcon(size);

  Border? get _outline =>
      outlined ? Border.all(color: Colors.black, width: 1) : null;

  // 교체 명단의 카드만 피그마처럼 색상 면 바깥에 테두리를 그려요.
  Border? get _cardOutline => substituteCardStyle
      ? Border.all(
          color: const Color(0xFF3D3D3D),
          width: 1,
          strokeAlign: BorderSide.strokeAlignOutside,
        )
      : _outline;

  Widget _buildIcon(double iconSize) {
    switch (type) {
      case LineupEventType.yellowCard:
        return SizedBox.square(
          dimension: iconSize,
          child: Center(
            child: Container(
              width: iconSize / 2,
              height: iconSize * 11 / 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(
                    substituteCardStyle ? 1 : iconSize / 8),
                border: _cardOutline,
              ),
            ),
          ),
        );
      case LineupEventType.secondYellowCard:
      case LineupEventType.redCard:
        return SizedBox.square(
          dimension: iconSize,
          child: Center(
            child: Container(
              width: iconSize / 2,
              height: iconSize * 11 / 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5C5C),
                borderRadius: BorderRadius.circular(
                    substituteCardStyle ? 1 : iconSize / 8),
                border: _cardOutline,
              ),
            ),
          ),
        );
      case LineupEventType.goal:
        return SvgPicture.asset(
          'assets/match_info/soccer_ball.svg',
          width: iconSize,
          height: iconSize,
        );
      case LineupEventType.assist:
        return Container(
          width: iconSize,
          height: iconSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: _outline,
          ),
          child: Text(
            'A',
            style: TextStyle(
              color: Colors.black,
              fontSize: iconSize * 2 / 3,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        );
      // 파일명과 달리 right 에셋은 위쪽, left 에셋은 아래쪽 화살표예요.
      case LineupEventType.subIn:
        return SvgPicture.asset(
          'assets/match_info/arrow_circle_right.svg',
          width: iconSize,
          height: iconSize,
        );
      case LineupEventType.subOut:
        return SvgPicture.asset(
          'assets/match_info/arrow_circle_left.svg',
          width: iconSize,
          height: iconSize,
        );
      case LineupEventType.injury:
        return SvgPicture.asset(
          'assets/match_info/add_circle.svg',
          width: iconSize,
          height: iconSize,
        );
    }
  }
}
