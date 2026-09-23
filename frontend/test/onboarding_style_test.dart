import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/auth/login_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.otf'))
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
    await fonts.load();
  });

  testWidgets('matches final Figma geometry and assets at 393 x 852',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: app_style.darktheme,
          debugShowCheckedModeBanner: false,
          locale: const Locale('ko'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: OnboardingScreen(
              loadOptions: () async => const LoginOptions(
                    recommended: [
                      LoginProvider.kakao,
                      LoginProvider.google,
                      LoginProvider.apple,
                      LoginProvider.email
                    ],
                    other: [LoginProvider.line],
                  )),
        )));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/auth/google.png'),
          tester.element(find.byType(OnboardingScreen)));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 좌표는 구현 계산식이 아니라 최종 Figma 프레임 5873:19688의 측정값이에요.
    final expected = <String, Rect>{
      'onboarding-logo': const Rect.fromLTWH(93, 115, 207, 30),
      'kakao-sign-in-button': const Rect.fromLTWH(24, 260, 345, 56),
      'google-sign-in-button': const Rect.fromLTWH(24, 332, 345, 56),
      'apple-sign-in-button': const Rect.fromLTWH(24, 404, 345, 56),
      'sign-in-username': const Rect.fromLTWH(24, 538, 345, 40),
      'sign-in-password': const Rect.fromLTWH(24, 624, 345, 40),
      'email-sign-in-button': const Rect.fromLTWH(24, 718, 345, 56),
    };
    for (final entry in expected.entries) {
      expect(tester.getRect(find.byKey(ValueKey(entry.key))), entry.value,
          reason: entry.key);
    }
    expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('forgot-password-link')))
            .dx,
        24);
    expect(find.text('또는'), findsNothing);
    expect(find.byKey(const ValueKey('other-login-methods')), findsNothing);
    expect(find.text('카카오로 계속하기'), findsOneWidget);
    for (final name in ['kakao', 'google', 'apple']) {
      final button = tester
          .widget<ElevatedButton>(find.byKey(ValueKey('$name-sign-in-button')));
      expect(button.style!.backgroundColor!.resolve({}),
          app_style.AppPalette.lightGrey);
      final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    }
    final svgSizes = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((w) => Size(w.width ?? 345, w.height!))
        .toList();
    expect(
        svgSizes,
        containsAll([
          const Size(207, 30),
          const Size(24, 24),
          const Size(23, 28),
          const Size(345, 2)
        ]));
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 1);
      final bytes = (await picture.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      final file = File('build/onboarding-final-ko.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      picture.dispose();
    });
  });
}
