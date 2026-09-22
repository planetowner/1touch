part of 'match_info_features.dart';

/// One event icon design shared by the summary, pitch, and substitutes.
class MatchEventIcon extends StatelessWidget {
  const MatchEventIcon({
    super.key,
    required this.type,
    this.size = 16,
    this.outlined = false,
  });

  final LineupEventType type;
  final double size;
  final bool outlined;

  @override
  Widget build(BuildContext context) => _buildIcon(size);

  Border? get _outline =>
      outlined ? Border.all(color: Colors.black, width: 1) : null;

  Border get _subtleOrDarkOutline => Border.all(
        color: outlined ? Colors.black : Colors.black.withValues(alpha: 0.08),
        width: 1,
      );

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
                borderRadius: BorderRadius.circular(iconSize / 8),
                border: _outline,
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
                color: const Color(0xFFE8000A),
                borderRadius: BorderRadius.circular(iconSize / 8),
                border: _outline,
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
      case LineupEventType.subIn:
        return Container(
          width: iconSize,
          height: iconSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: _subtleOrDarkOutline,
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            size: iconSize * 0.75,
            color: Color(0xFF20B972),
          ),
        );
      case LineupEventType.subOut:
        return Container(
          width: iconSize,
          height: iconSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: _subtleOrDarkOutline,
          ),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: iconSize * 0.75,
            color: Color(0xFFFF4F5E),
          ),
        );
      case LineupEventType.injury:
        return Container(
          width: iconSize,
          height: iconSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: _subtleOrDarkOutline,
          ),
          child: Icon(
            Icons.add,
            size: iconSize * 5 / 6,
            color: Color(0xFFFF4F5E),
          ),
        );
    }
  }
}
