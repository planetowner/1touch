import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';

void main() {
  setUp(() => appLocaleController.value = const Locale('en'));
  tearDown(() => appLocaleController.value = const Locale('en'));

  test('Korean typography matches the Pretendard design scale', () {
    final styles = <TextStyle>[
      KoreanHeading1.style,
      KoreanHeading2.style,
      KoreanHeading3.style,
      KoreanHeading4.style,
      KoreanHeading5.style,
      KoreanBody1.style,
      KoreanBody2.style,
      KoreanBody1Bold.style,
      KoreanBody2Bold.style,
      KoreanEyebrow.style,
    ];

    expect(styles.every((style) => style.fontFamily == 'Archivo'), isTrue);
    expect(
      styles.every(
        (style) => style.fontFamilyFallback?.contains('Pretendard') ?? false,
      ),
      isTrue,
    );

    expect(
      styles.map((style) => style.fontSize),
      [44, 28, 22, 18, 16, 15, 14, 15, 14, 12],
    );
    expect(
      styles.map((style) => style.height),
      [1.4, 1.4, 1.5, 1.5, 1.6, 1.6, 1.6, 1.6, 1.6, 1.6],
    );

    expect(KoreanHeading1.style.letterSpacing, -0.88);
    expect(KoreanHeading2.style.letterSpacing, -0.56);
    expect(KoreanHeading3.style.letterSpacing, -0.44);
    expect(KoreanHeading4.style.letterSpacing, -0.36);
    expect(KoreanHeading5.style.letterSpacing, -0.32);
    expect(KoreanEyebrow.style.letterSpacing, -0.24);
  });

  test('shared typography follows the locale controller', () {
    expect(Heading1.style.fontFamily, 'Archivo');
    expect(Heading1.style.fontSize, 48);
    expect(Heading5.style.fontSize, 18);
    expect(Body2.style.height, 1.2);

    appLocaleController.value = const Locale('ko');

    expect(Heading1.style, KoreanHeading1.style);
    expect(Heading1.style.fontSize, 44);
    expect(Heading5.style, KoreanHeading5.style);
    expect(Heading5.style.fontSize, 16);
    expect(Body2.style, KoreanBody2.style);
    expect(Body2.style.height, 1.6);
    expect(Body1_b.style, KoreanBody1Bold.style);
    expect(Body2_b.style, KoreanBody2Bold.style);
    expect(Eyebrow.style, KoreanEyebrow.style);
  });

  test('theme font family follows the selected locale in both modes', () {
    for (final theme in [
      app_style.lightThemeForLocale(const Locale('ko')),
      app_style.darkThemeForLocale(const Locale('ko')),
    ]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Archivo');
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        contains('Pretendard'),
      );
    }

    for (final theme in [
      app_style.lightThemeForLocale(const Locale('en')),
      app_style.darkThemeForLocale(const Locale('en')),
    ]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Archivo');
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback, isNull);
    }
  });
}
