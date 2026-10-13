import 'package:flutter/material.dart';

class DrawTeamLogos extends StatelessWidget {
  const DrawTeamLogos({
    super.key,
    required this.homeLogo,
    required this.awayLogo,
    required this.keyPrefix,
  });

  final Widget homeLogo;
  final Widget awayLogo;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              key: ValueKey('$keyPrefix-home-clip'),
              clipper: const _DrawLogoHalfClipper(keepTopLeft: true),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.square(
                  key: ValueKey('$keyPrefix-home-logo'),
                  dimension: 36,
                  child: homeLogo,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              key: ValueKey('$keyPrefix-away-clip'),
              clipper: const _DrawLogoHalfClipper(keepTopLeft: false),
              child: Align(
                alignment: Alignment.bottomRight,
                child: SizedBox.square(
                  key: ValueKey('$keyPrefix-away-logo'),
                  dimension: 36,
                  child: awayLogo,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DrawLogoDividerPainter(
                  Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      );
}

class _DrawLogoHalfClipper extends CustomClipper<Path> {
  const _DrawLogoHalfClipper({required this.keepTopLeft});

  final bool keepTopLeft;

  @override
  Path getClip(Size size) => keepTopLeft
      ? (Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close())
      : (Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close());

  @override
  bool shouldReclip(_DrawLogoHalfClipper oldClipper) =>
      keepTopLeft != oldClipper.keepTopLeft;
}

class _DrawLogoDividerPainter extends CustomPainter {
  const _DrawLogoDividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DrawLogoDividerPainter oldDelegate) =>
      color != oldDelegate.color;
}
