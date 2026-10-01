import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/l10n/app_localizations.dart';

import 'rolling_football_motion.dart';

/// The 56px loading mark for page and section content areas.
class FootballLoadingIndicator extends StatelessWidget {
  const FootballLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final ball = SvgPicture.asset(
      'assets/match_info/soccer_ball.svg',
      width: 56,
      height: 56,
    );
    return Semantics(
      label: tr(context, 'Loading…'),
      child: SizedBox.square(
        dimension: 56,
        child: RollingFootballMotion(
          transformKey: const ValueKey('football-loading-motion'),
          child: Theme.of(context).brightness == Brightness.dark
              ? ball
              : ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1,
                    0,
                    0,
                    0,
                    255,
                    0,
                    -1,
                    0,
                    0,
                    255,
                    0,
                    0,
                    -1,
                    0,
                    255,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
                  child: ball,
                ),
        ),
      ),
    );
  }
}
