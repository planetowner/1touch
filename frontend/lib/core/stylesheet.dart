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
  );
}

class KoreanBody1 {
  static const TextStyle style = TextStyle(
    fontSize: 15,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w400,
    height: 1.60,
  );
}

class KoreanBody2 {
  static const TextStyle style = TextStyle(
    fontSize: 14,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w400,
    height: 1.60,
  );
}

class KoreanBody1Bold {
  static const TextStyle style = TextStyle(
    fontSize: 15,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.60,
  );
}

class KoreanBody2Bold {
  static const TextStyle style = TextStyle(
    fontSize: 14,
    fontFamily: _latinFontFamily,
    fontFamilyFallback: _koreanFontFallback,
    fontWeight: FontWeight.w700,
    height: 1.60,
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
  );
}
