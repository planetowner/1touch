// ignore_for_file: camel_case_types

import 'package:flutter/material.dart';
import 'package:onetouch/core/locale_controller.dart';

TextStyle _localizedStyle(TextStyle english, TextStyle korean) =>
    appLocaleController.value.languageCode == 'ko' ? korean : english;

const _latinFontFamily = 'Archivo';
const _koreanFontFallback = <String>['Pretendard'];

class Heading1 {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 48,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanHeading1.style);

  /// Locale-independent Archivo style for scores and other numeric-only UI.
  static const TextStyle latinStyle = _englishStyle;
}

class Heading2 {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 32,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanHeading2.style);

  /// Locale-independent Archivo style for scores and other numeric-only UI.
  static const TextStyle latinStyle = _englishStyle;
}

class Heading3 {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 24,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanHeading3.style);

  /// Locale-independent Archivo style for scores and other numeric-only UI.
  static const TextStyle latinStyle = _englishStyle;
}

class Heading4 {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 20,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanHeading4.style);
}

class Heading5 {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 18,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanHeading5.style);
}

class Body1 {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 15,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w400,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanBody1.style);
}

class Body2 {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 14,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w400,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanBody2.style);
}

class Body1_b {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 15,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanBody1Bold.style);
}

class Body2_b {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 14,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanBody2Bold.style);
}

class Eyebrow {
  static const TextStyle _englishStyle = TextStyle(
    fontSize: 12,
    fontFamily: 'Archivo',
    fontWeight: FontWeight.w400,
    height: 1.20,
  );

  static TextStyle get style =>
      _localizedStyle(_englishStyle, KoreanEyebrow.style);
}

/// Korean typography tokens from the Pretendard type scale.
///
/// These mirror the English Archivo tokens above while preserving the sizes,
/// line heights, and letter spacing defined for Korean text.
class KoreanHeading1 {
  static const TextStyle style = TextStyle(
    fontSize: 44,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.40,
    letterSpacing: -0.88,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanHeading2 {
  static const TextStyle style = TextStyle(
    fontSize: 28,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.40,
    letterSpacing: -0.56,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanHeading3 {
  static const TextStyle style = TextStyle(
    fontSize: 22,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.50,
    letterSpacing: -0.44,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanHeading4 {
  static const TextStyle style = TextStyle(
    fontSize: 18,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.50,
    letterSpacing: -0.36,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanHeading5 {
  static const TextStyle style = TextStyle(
    fontSize: 16,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.60,
    letterSpacing: -0.32,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanBody1 {
  static const TextStyle style = TextStyle(
    fontSize: 15,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w400,
    height: 1.60,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanBody2 {
  static const TextStyle style = TextStyle(
    fontSize: 14,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w400,
    height: 1.60,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanBody1Bold {
  static const TextStyle style = TextStyle(
    fontSize: 15,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.60,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanBody2Bold {
  static const TextStyle style = TextStyle(
    fontSize: 14,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.60,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class KoreanEyebrow {
  static const TextStyle style = TextStyle(
    fontSize: 12,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w400,
    height: 1.60,
    letterSpacing: -0.24,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
