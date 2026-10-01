import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/loading/rolling_football_motion.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// The fixed Home shortcut to the currently viewed team's live fixture.
class LiveMatchBallButton extends StatelessWidget {
  const LiveMatchBallButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

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
          onTap: onPressed,
          child: Semantics(
            button: true,
            label: tr(context, 'Open live match'),
            child: Center(
              child: RollingFootballMotion(
                transformKey: const ValueKey('home-live-match-ball-motion'),
                child: SvgPicture.asset(
                  'assets/sports_and_outdoors.svg',
                  width: 72,
                  height: 72,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
