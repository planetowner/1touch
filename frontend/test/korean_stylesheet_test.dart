import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/stylesheet.dart';

void main() {
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

    expect(styles.every((style) => style.fontFamily == 'Pretendard'), isTrue);

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
}
