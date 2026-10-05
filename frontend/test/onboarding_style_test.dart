import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/SignComps/other_login_methods.dart';
import 'package:onetouch/core/locale_controller.dart';
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

  testWidgets('LINE sign-in button uses the supplied SVG icon', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        loadOptions: () async => const LoginOptions(
          recommended: [LoginProvider.line, LoginProvider.email],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final icon = tester.widget<SvgPicture>(find.descendant(
      of: find.byKey(const ValueKey('line-sign-in-button')),
      matching: find.byType(SvgPicture),
    ));
    expect(icon.width, 24);
    expect(icon.height, 24);
    expect(
        (icon.bytesLoader as SvgAssetLoader).assetName, 'assets/auth/line.svg');
    expect(tester.takeException(), isNull);
  });

  testWidgets('other login methods exclude email and duplicate providers',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => OnboardingScreen(
          loadOptions: () async => const LoginOptions(
            recommended: [LoginProvider.google, LoginProvider.email],
            other: [
              LoginProvider.google,
              LoginProvider.line,
              LoginProvider.line,
              LoginProvider.email,
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/auth/other-methods',
        builder: (_, state) => OtherLoginMethodsScreen(
          initialOptions: state.extra as LoginOptions?,
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final otherMethods = find.byKey(const ValueKey('other-login-methods'));
    expect(otherMethods, findsOneWidget);
    expect(find.byKey(const ValueKey('line-sign-in-button')), findsNothing);
    expect(
      tester.getRect(otherMethods).top -
          tester
              .getRect(find.byKey(const ValueKey('google-sign-in-button')))
              .bottom,
      16,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('google-sign-in-button'))).top -
          tester
              .getRect(find.byKey(const ValueKey('onboarding-divider')))
              .bottom,
      32,
    );
    await tester.tap(otherMethods);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('google-sign-in-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-sign-in-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('email-sign-in-button')), findsNothing);
    final googleButton =
        tester.getRect(find.byKey(const ValueKey('google-sign-in-button')));
    final lineButton =
        tester.getRect(find.byKey(const ValueKey('line-sign-in-button')));
    final header =
        tester.getRect(find.byKey(const ValueKey('other-login-header')));
    expect(googleButton.height, 56);
    expect(googleButton.top - header.bottom, 24);
    expect(lineButton.top - googleButton.bottom, 16);
    await tester.tap(find.byKey(const ValueKey('other-login-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('email-sign-in-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('line-sign-in-button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches the supplied login design at 393 x 852', (tester) async {
    final previousLocale = appLocaleController.value;
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = previousLocale);
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
                    other: [],
                  )),
        )));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/auth/google.png'),
          tester.element(find.byType(OnboardingScreen)));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // 좌표는 393 x 852 로그인 디자인의 고정 치수와 간격을 확인해요.
    final expected = <String, Rect>{
      'onboarding-logo': const Rect.fromLTWH(93, 151, 207, 30),
      'sign-in-username': const Rect.fromLTWH(24, 362, 345, 44),
      'sign-in-password': const Rect.fromLTWH(24, 452, 345, 44),
      'email-sign-in-button': const Rect.fromLTWH(24, 558, 345, 56),
      'onboarding-divider': const Rect.fromLTWH(24, 676, 345, 2),
      'kakao-sign-in-button': const Rect.fromLTWH(96.5, 710, 56, 56),
      'google-sign-in-button': const Rect.fromLTWH(168.5, 710, 56, 56),
      'apple-sign-in-button': const Rect.fromLTWH(240.5, 710, 56, 56),
    };
    for (final entry in expected.entries) {
      expect(tester.getRect(find.byKey(ValueKey(entry.key))), entry.value,
          reason: entry.key);
    }
    final emailLabel = find
        .ancestor(
          of: find.text('이메일 또는 아이디').first,
          matching: find.byType(SizedBox),
        )
        .first;
    final passwordLabel = find
        .ancestor(
          of: find.text('비밀번호').first,
          matching: find.byType(SizedBox),
        )
        .first;
    expect(
        tester.getRect(find.byKey(const ValueKey('sign-in-username'))).top -
            tester.getRect(emailLabel).bottom,
        8);
    expect(
        tester.getRect(passwordLabel).top -
            tester
                .getRect(find.byKey(const ValueKey('sign-in-username')))
                .bottom,
        16);
    expect(
        tester.getRect(find.byKey(const ValueKey('sign-in-password'))).top -
            tester.getRect(passwordLabel).bottom,
        8);
    final passwordField =
        tester.getRect(find.byKey(const ValueKey('sign-in-password')));
    final visibilityIcon = tester.getRect(find.descendant(
      of: find.byKey(const ValueKey('sign-in-password-visibility')),
      matching: find.byType(SvgPicture),
    ));
    expect(passwordField.right - visibilityIcon.right, 8);
    expect(visibilityIcon.center.dy, passwordField.center.dy);
    for (final pair in [
      ('kakao-sign-in-button', 'google-sign-in-button'),
      ('google-sign-in-button', 'apple-sign-in-button'),
    ]) {
      final previous = tester.getRect(find.byKey(ValueKey(pair.$1)));
      final next = tester.getRect(find.byKey(ValueKey(pair.$2)));
      expect(next.left - previous.right, 16,
          reason: '${pair.$1} to ${pair.$2}');
    }
    expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('forgot-password-link')))
            .dx,
        24);
    expect(find.text('또는'), findsNothing);
    expect(find.byKey(const ValueKey('other-login-methods')), findsOneWidget);
    expect(find.text('다른 방식으로 로그인하기'), findsOneWidget);
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

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('keeps login dimensions and light colors at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: OnboardingScreen(
          loadOptions: () async => const LoginOptions(recommended: [
            LoginProvider.kakao,
            LoginProvider.google,
            LoginProvider.apple,
            LoginProvider.email,
          ]),
        ),
      ));
      await tester.pumpAndSettle();

      final expectedWidth = (size.width - 48).clamp(0, 345);
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          app_style.AppPalette.white);
      for (final key in [
        'sign-in-username',
        'sign-in-password',
        'email-sign-in-button',
        'onboarding-divider',
      ]) {
        expect(tester.getSize(find.byKey(ValueKey(key))).width, expectedWidth);
      }
      expect(
          tester.getSize(find.byKey(const ValueKey('sign-in-username'))).height,
          44);
      expect(
          tester.getSize(find.byKey(const ValueKey('sign-in-password'))).height,
          44);
      expect(
          tester
              .getSize(find.byKey(const ValueKey('email-sign-in-button')))
              .height,
          56);
      for (final provider in ['kakao', 'google', 'apple']) {
        final buttonFinder = find.byKey(ValueKey('$provider-sign-in-button'));
        expect(tester.getSize(buttonFinder), const Size(56, 56));
        final button = tester.widget<ElevatedButton>(buttonFinder);
        expect(button.style!.backgroundColor!.resolve({}),
            app_style.AppPalette.lightModeDarkGrey);
      }
      final username = tester
          .widget<TextField>(find.byKey(const ValueKey('sign-in-username')));
      expect(username.decoration!.fillColor, app_style.AppPalette.lightGreyBox);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('password visibility toggles inside the login input',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        loadOptions: () async =>
            const LoginOptions(recommended: [LoginProvider.email]),
      ),
    ));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('sign-in-password'));
    final visibility =
        find.byKey(const ValueKey('sign-in-password-visibility'));

    await tester.enterText(field, 'secret123');
    expect(tester.widget<TextField>(field).obscureText, isTrue);
    await tester.tap(visibility);
    await tester.pump();
    expect(tester.widget<TextField>(field).obscureText, isFalse);
    expect(tester.widget<TextField>(field).controller!.text, 'secret123');
    await tester.tap(visibility);
    await tester.pump();
    expect(tester.widget<TextField>(field).obscureText, isTrue);
    expect(tester.takeException(), isNull);
  });
}
