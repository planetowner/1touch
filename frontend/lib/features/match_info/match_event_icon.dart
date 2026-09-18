part of 'match_info_features.dart';

/// One event icon design shared by the summary, pitch, and substitutes.
class MatchEventIcon extends StatelessWidget {
  const MatchEventIcon({super.key, required this.type, this.size = 16});

  final LineupEventType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LineupEventType.yellowCard:
        return SizedBox.square(
          dimension: size,
          child: Center(
            child: Container(
              width: size * 7 / 12,
              height: size * 10 / 12,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(size / 8),
              ),
            ),
          ),
        );
      case LineupEventType.secondYellowCard:
      case LineupEventType.redCard:
        return SizedBox.square(
          dimension: size,
          child: Center(
            child: Container(
              width: size * 7 / 12,
              height: size * 10 / 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE8000A),
                borderRadius: BorderRadius.circular(size / 8),
              ),
            ),
          ),
        );
      case LineupEventType.goal:
        return SvgPicture.asset(
          'assets/match_info/soccer_ball.svg',
          width: size,
          height: size,
        );
      case LineupEventType.assist:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Text(
            'A',
            style: TextStyle(
              color: Colors.black,
              fontSize: size * 2 / 3,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        );
      case LineupEventType.subIn:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: size * 0.75,
            color: Color(0xFF20B972),
          ),
        );
      case LineupEventType.subOut:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: size * 0.75,
            color: Color(0xFFFF4F5E),
          ),
        );
      case LineupEventType.injury:
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Icon(
            Icons.add,
            size: size * 5 / 6,
            color: Color(0xFFFF4F5E),
          ),
        );
    }
  }
}
