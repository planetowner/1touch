import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_error_config.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/app_error_view.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  test('uses the configured Korean error copy without changing it', () {
    const locale = Locale('ko');
    expect(appErrorConfigs, hasLength(8));
    expect(
      appErrorConfigs.map(
        (code, config) => MapEntry(code, {
          'title': translateMessage(locale, config.title),
          'message': translateMessage(locale, config.message),
          'action': config.action == null
              ? null
              : translateMessage(locale, config.action!),
        }),
      ),
      {
        404: {
          'title': '오프사이드!',
          'message': '찾고 있는 페이지를 찾을 수 없어요.',
          'action': '홈으로',
        },
        401: {
          'title': '다시 입장해주세요',
          'message': '로그인 세션이 만료됐어요.',
          'action': '다시 로그인',
        },
        403: {
          'title': '레드카드!',
          'message': '이 페이지에 접근할 권한이 없어요.',
          'action': '돌아가기',
        },
        429: {
          'title': '잠시 벤치에서 쉬어가요',
          'message': '요청이 너무 많아요. 잠시 후 다시 시도해주세요.',
          'action': '홈으로',
        },
        500: {
          'title': 'VAR 확인 중',
          'message': '서버에 문제가 생겼어요. 잠시 후 다시 시도해주세요.',
          'action': '다시 시도',
        },
        502: {
          'title': '패스 연결에 실패했어요',
          'message': '서버 간 연결에 문제가 생겼어요. 잠시 후 다시 시도해주세요.',
          'action': '돌아가기',
        },
        503: {
          'title': '잠시 경기 중단',
          'message': '현재 서비스를 이용할 수 없어요. 잠시 후 다시 시도해주세요.',
          'action': '돌아가기',
        },
        504: {
          'title': '추가시간을 넘겼어요',
          'message': '서버 응답이 지연되고 있어요. 다시 시도해주세요.',
          'action': '홈으로',
        },
      },
    );
  });

  test('matches each error status to its photo', () {
    expect(
      appErrorConfigs.map((code, config) => MapEntry(code, config.imageAsset)),
      {
        404: 'assets/error_offside.png',
        401: 'assets/error_session_expired.png',
        403: 'assets/error_forbidden.png',
        429: 'assets/error_rate_limit.png',
        500: 'assets/error_server.png',
        502: 'assets/error_gateway.png',
        503: 'assets/error_unavailable.png',
        504: 'assets/error_timeout.png',
      },
    );
  });

  testWidgets('only the offside photo is enlarged', (tester) async {
    for (final statusCode in [404, 503]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          theme: app_style.darktheme,
          home: Scaffold(body: AppErrorView(statusCode: statusCode)),
        ),
      );

      final photo = tester.widget<Transform>(
        find.byKey(const ValueKey('app-error-photo-scale')),
      );
      expect(photo.alignment, Alignment.topCenter);
      expect(photo.transform.getMaxScaleOnAxis(), statusCode == 404 ? 1.25 : 1);
    }
  });

  for (final statusCode in [401, 403, 404, 429, 500, 502, 503, 504]) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      for (final brightness in [Brightness.dark, Brightness.light]) {
        testWidgets('$statusCode photo error fits $size in $brightness',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('ko'),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationDelegates,
              theme: brightness == Brightness.dark
                  ? app_style.darktheme
                  : app_style.whitetheme,
              home: Scaffold(
                body: AppErrorView(statusCode: statusCode, onAction: () {}),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('app-error-photo-fade')),
              findsOneWidget);
          expect(find.byKey(ValueKey('app-error-$statusCode-action')),
              findsOneWidget);
          final button = tester.widget<FilledButton>(
            find.byKey(ValueKey('app-error-$statusCode-action')),
          );
          expect(
            button.style!.backgroundColor!.resolve({}),
            brightness == Brightness.dark
                ? app_style.AppPalette.white
                : app_style.AppPalette.black,
          );
          expect(
            (tester.widget<Image>(find.byType(Image)).image as AssetImage)
                .assetName,
            appErrorConfigFor(statusCode).imageAsset,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('shows and runs a configured action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.whitetheme,
        home: Scaffold(
          body: AppErrorView(
            statusCode: 404,
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('오프사이드!'), findsOneWidget);
    expect(find.text('찾고 있는 페이지를 찾을 수 없어요.'), findsOneWidget);
    expect(appErrorConfigFor(404).imageAsset, 'assets/error_offside.png');
    expect(find.byType(Image), findsOneWidget);
    final fade = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('app-error-photo-fade')),
    );
    final gradient =
        (fade.decoration as BoxDecoration).gradient! as RadialGradient;
    expect(gradient.center, Alignment.topCenter);
    final size = MediaQuery.sizeOf(tester.element(find.byType(AppErrorView)));
    final bottomInset = MediaQuery.viewPaddingOf(
      tester.element(find.byType(AppErrorView)),
    ).bottom;
    expect(
      gradient.radius,
      closeTo((size.height - bottomInset - 300) / (size.width * 0.85), 0.001),
    );
    expect(gradient.stops, [0.0, 0.58, 0.78, 0.85]);
    expect(
        gradient.colors.last,
        app_style.AppColors.of(
          tester.element(find.byType(AppErrorView)),
        ).pageBackground);
    await tester.tap(find.text('홈으로'));
    expect(tapped, isTrue);
  });

  testWidgets('photo error fits a compact screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darktheme,
        home: const Scaffold(body: AppErrorView(statusCode: 404)),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('app-error-photo-fade')), findsOneWidget);
  });

  testWidgets('uses the reference spacing between message and action',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darktheme,
        home: Scaffold(
          body: AppErrorView(statusCode: 429, onAction: () {}),
        ),
      ),
    );

    final messageBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('app-error-429-message')))
        .dy;
    final buttonTop = tester
        .getTopLeft(find.byKey(const ValueKey('app-error-429-action')))
        .dy;
    expect(buttonTop - messageBottom, 140);
  });

  for (final statusCode in [429, 504]) {
    testWidgets('$statusCode action opens home', (tester) async {
      final router = GoRouter(
        initialLocation: '/error',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('Home page')),
          GoRoute(
            path: '/error',
            builder: (_, __) => AppErrorScreen(statusCode: statusCode),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darktheme,
      ));

      await tester.tap(find.byKey(ValueKey('app-error-$statusCode-action')));
      await tester.pumpAndSettle();
      expect(find.text('Home page'), findsOneWidget);
    });
  }

  for (final statusCode in [502, 503]) {
    testWidgets('$statusCode action returns to the previous page',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/previous',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Text('Home page')),
          GoRoute(
            path: '/previous',
            builder: (_, __) => const Text('Previous page'),
          ),
          GoRoute(
            path: '/error',
            builder: (_, __) => AppErrorScreen(statusCode: statusCode),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.darktheme,
      ));
      router.push('/error');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('app-error-$statusCode-action')));
      await tester.pumpAndSettle();
      expect(find.text('Previous page'), findsOneWidget);
    });
  }

  testWidgets('back action opens home when there is no previous page',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/error',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const Text('Home page')),
        GoRoute(
          path: '/error',
          builder: (_, __) => const AppErrorScreen(statusCode: 502),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      theme: app_style.darktheme,
    ));

    await tester.tap(find.byKey(const ValueKey('app-error-502-action')));
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
  });
}
