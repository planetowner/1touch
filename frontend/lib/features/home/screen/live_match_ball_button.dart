import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// The fixed Home shortcut to the currently viewed team's live fixture.
class LiveMatchBallButton extends StatefulWidget {
  const LiveMatchBallButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<LiveMatchBallButton> createState() => _LiveMatchBallButtonState();
}

class _LiveMatchBallButtonState extends State<LiveMatchBallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('home-live-match-button'),
      width: 72,
      height: 72,
      child: Material(
        color: AppPalette.white,
        shape: const CircleBorder(),
        elevation: 5,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          child: Semantics(
            button: true,
            label: tr(context, 'Open live match'),
            child: Center(
              child: AnimatedBuilder(
                animation: _roll,
                child: SvgPicture.asset(
                  'assets/sports_and_outdoors.svg',
                  width: 72,
                  height: 72,
                ),
                builder: (context, ball) {
                  final progress = Curves.easeInOut.transform(_roll.value);
                  return Transform.translate(
                    key: const ValueKey('home-live-match-ball-motion'),
                    offset: Offset(-5 + 10 * progress, 0),
                    child: Transform.rotate(
                      angle: -0.6 + 1.2 * progress,
                      child: ball,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
