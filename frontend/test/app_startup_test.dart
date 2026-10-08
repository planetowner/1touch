import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:onetouch/core/community_link_navigation.dart';
import 'package:onetouch/onboarding.dart';
import 'package:onetouch/main.dart' as app;
import 'package:onetouch/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onetouch/core/theme_controller.dart';

void main() {
  testWidgets('saved light theme is used on the first Flutter splash frame',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app.theme_mode': 'light'});
    final platform = Completer<void>();
    await tester.runAsync(
      () => AssetLottie('assets/animations/onetouch_logo_light.json').load(),
    );

    await app.runOneTouchApp(
      initializePlatform: () => platform.future,
      restoreSession: () async => false,
    );
    await tester.pump();
    await tester.pump();

    expect(appThemeController.value, ThemeMode.light);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    expect(
      find.byKey(const ValueKey('assets/animations/onetouch_logo_light.json')),
      findsOneWidget,
    );
    platform.complete();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'logo precedes initialization and navigation does not wait for push',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});

    // 실제 로고를 미리 읽고, 테스트 시계로 애니메이션과 화면 전환을 확인해요.
    await tester.runAsync(
      () => AssetLottie('assets/animations/onetouch_logo_dark.json').load(),
    );

    final platform = Completer<void>();
    final restore = Completer<bool>();
    final push = Completer<void>();
    var platformStarted = false;
    var restoreStarted = false;
    var pushStarted = false;
    await app.runOneTouchApp(
      initializePlatform: () {
        platformStarted = true;
        expect(find.byType(SplashScreen), findsOneWidget);
        return platform.future;
      },
      restoreSession: () {
        restoreStarted = true;
        return restore.future;
      },
      startPushServices: () {
        pushStarted = true;
        return push.future;
      },
    );
    await tester.pump();
    await tester.pump();
    expect(platformStarted, isTrue);
    expect(restoreStarted, isFalse);
    expect(find.byType(Lottie).hitTestable(), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(SplashScreen)));
    router.go('/community/123');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    expect(find.byType(SplashScreen), findsOneWidget);
    platform.complete();
    await tester.pumpAndSettle();
    expect(restoreStarted, isTrue);
    expect(pushStarted, isFalse);
    expect(find.byType(OnboardingScreen), findsNothing);
    restore.complete(false);
    await tester.pumpAndSettle();

    expect(pushStarted, isTrue);
    expect(push.isCompleted, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    // API 설정이 없는 테스트에서도 첫 화면과 재시도 안내까지 렌더링해요.
    expect(find.text('Unable to load login methods. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(communityLinkNavigation.take(sessionToken: 'later-login'),
        '/community/123');
    push.complete();
    await tester.pump();
  });
}
