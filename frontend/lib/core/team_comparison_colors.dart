import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onetouch/data/teams/team_color_palette_2627.dart';

class ColorUtils {
  const ColorUtils._();

  /// WCAG 2.1 contrast ratio in the 1.0–21.0 range.
  static double getContrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final lightest = math.max(firstLuminance, secondLuminance);
    final darkest = math.min(firstLuminance, secondLuminance);
    return (lightest + 0.05) / (darkest + 0.05);
  }

  /// Perceptual distance between two sRGB colors in OKLab.
  static double okLabDistance(Color first, Color second) {
    final firstLab = _rgbToOkLab(first);
    final secondLab = _rgbToOkLab(second);
    return math.sqrt(
      math.pow(firstLab.$1 - secondLab.$1, 2) +
          math.pow(firstLab.$2 - secondLab.$2, 2) +
          math.pow(firstLab.$3 - secondLab.$3, 2),
    );
  }

  static (double, double, double) _rgbToOkLab(Color color) {
    double linearize(double component) => component > 0.04045
        ? math.pow((component + 0.055) / 1.055, 2.4).toDouble()
        : component / 12.92;

    final red = linearize(color.r);
    final green = linearize(color.g);
    final blue = linearize(color.b);

    final l = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue;
    final m = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue;
    final s = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue;

    final lCbrt = _cubeRoot(l);
    final mCbrt = _cubeRoot(m);
    final sCbrt = _cubeRoot(s);

    return (
      0.2104542553 * lCbrt + 0.7936177850 * mCbrt - 0.0040720403 * sCbrt,
      1.9779984951 * lCbrt - 2.4285922050 * mCbrt + 0.4505937099 * sCbrt,
      0.0259040371 * lCbrt + 0.7827717662 * mCbrt - 0.8086757973 * sCbrt,
    );
  }

  static double _cubeRoot(double value) => value < 0
      ? -math.pow(-value, 1 / 3).toDouble()
      : math.pow(value, 1 / 3).toDouble();
}

class ResolvedTeamPalette {
  const ResolvedTeamPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  List<Color> get orderedColors => [primary, secondary, tertiary];
}

class TeamComparisonColors {
  const TeamComparisonColors({
    required this.anchor,
    required this.opponent,
  });

  final Color anchor;
  final Color opponent;
}

class TeamComparisonColorResolver {
  const TeamComparisonColorResolver._();

  static const double minimumOkLabDistance = 0.12;
  static const double minimumBackgroundContrast = 2.5;
  static const Color fallbackColor = Colors.white;
  static const Color fallbackPrimary = Color(0xFFFF5C5C);

  static ResolvedTeamPalette paletteFor({
    String? teamName,
    Color? primaryFallback,
  }) {
    final palette = teamName == null ? null : teamColorPaletteForName(teamName);
    final primary = palette == null
        ? (primaryFallback ?? fallbackPrimary)
        : Color(palette.primary);
    return ResolvedTeamPalette(
      primary: primary,
      secondary: palette == null ? primary : Color(palette.secondary),
      tertiary: palette == null ? primary : Color(palette.tertiary),
    );
  }

  static TeamComparisonColors resolve({
    String? anchorTeamName,
    Color? anchorPrimaryFallback,
    String? opponentTeamName,
    Color? opponentPrimaryFallback,
    required Color background,
  }) {
    final anchorPalette = paletteFor(
      teamName: anchorTeamName,
      primaryFallback: anchorPrimaryFallback,
    );
    final opponentPalette = paletteFor(
      teamName: opponentTeamName,
      primaryFallback: opponentPrimaryFallback,
    );
    return TeamComparisonColors(
      anchor: anchorPalette.primary,
      opponent: resolveOpponentColor(
        anchor: anchorPalette.primary,
        candidates: opponentPalette.orderedColors,
        background: background,
      ),
    );
  }

  static Color resolveOpponentColor({
    required Color anchor,
    required Iterable<Color> candidates,
    required Color background,
    double minimumDistance = minimumOkLabDistance,
    double minimumContrast = minimumBackgroundContrast,
  }) {
    for (final candidate in candidates) {
      final isDistinct =
          ColorUtils.okLabDistance(anchor, candidate) >= minimumDistance;
      final isVisible =
          ColorUtils.getContrastRatio(candidate, background) >= minimumContrast;
      if (isDistinct && isVisible) return candidate;
    }
    return fallbackColor;
  }
}
