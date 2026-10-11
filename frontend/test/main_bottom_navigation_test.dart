import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/main.dart';
import 'package:onetouch/core/bottom_navigation.dart';

import 'support/app_catalog.dart';
import 'support/app_fonts.dart';

void main() {
  setUpAppCatalog();
  const testCases = [
    (size: Size(320, 568), bottomInset: 0.0),
    (size: Size(430, 932), bottomInset: 34.0),
  ];

  setUpAll(loadAppFonts);

  for (final testCase in testCases) {
    for (final language in ['en', 'ko']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final size = testCase.size;
        testWidgets(
            'bottom navigation matches Figma at $size $language $brightness',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = FakeViewPadding(bottom: testCase.bottomInset);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final previousLocale = appLocaleController.value;
          appLocaleController.value = Locale(language);
          addTearDown(() => appLocaleController.value = previousLocale);

          var selectedIndex = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationDelegates,
              theme: brightness == Brightness.dark
                  ? app_style.darktheme
                  : app_style.whitetheme,
              home: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: const SizedBox.expand(),
                  bottomNavigationBar: OneTouchBottomNavigationBar(
                    currentIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final bar = tester.getRect(find.byType(OneTouchBottomNavigationBar));
          final labels = language == 'ko'
              ? ['홈', '팀', '선수', '커뮤니티']
              : ['Home', 'Team', 'Players', 'Community'];
          final labelHeight = language == 'ko' ? 22.0 : 18.0;
          final bottomPadding = testCase.bottomInset == 0 ? 32.0 : 34.0;
          expect(bar.height, 12 + 32 + 8 + labelHeight + bottomPadding);
          final itemRects = <Rect>[];
          for (var index = 0; index < labels.length; index++) {
            final item = find.byKey(ValueKey('main-bottom-navigation-$index'));
            final icon =
                find.descendant(of: item, matching: find.byType(SvgPicture));
            final label =
                find.descendant(of: item, matching: find.text(labels[index]));
            final iconRect = tester.getRect(icon);
            final labelRect = tester.getRect(label);
            itemRects.add(tester.getRect(item));
            expect(tester.getSize(icon), const Size(32, 32));
            expect(iconRect.top - bar.top, 12);
            expect(labelRect.top - iconRect.bottom, 8);
            expect(labelRect.height, labelHeight);
            expect(bar.bottom - labelRect.bottom, bottomPadding);
          }
          expect(itemRects.first.left, 24);
          expect(size.width - itemRects.last.right, 24);
          final gap = itemRects[1].left - itemRects[0].right;
          for (var index = 2; index < itemRects.length; index++) {
            expect(itemRects[index].left - itemRects[index - 1].right,
                closeTo(gap, 0.01));
          }

          const assets = ['home', 'team', 'players', 'community'];
          for (var selection = 0; selection < assets.length; selection++) {
            await tester
                .tap(find.byKey(ValueKey('main-bottom-navigation-$selection')));
            await tester.pumpAndSettle();
            expect(selectedIndex, selection);
            for (var index = 0; index < assets.length; index++) {
              final icon = tester.widget<SvgPicture>(find.descendant(
                of: find.byKey(ValueKey('main-bottom-navigation-$index')),
                matching: find.byType(SvgPicture),
              ));
              final suffix = selection == index ? '_active' : '';
              expect((icon.bytesLoader as SvgAssetLoader).assetName,
                  'assets/navigation/${assets[index]}$suffix.svg');
            }
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final isDark in [false, true]) {
    testWidgets('navigation icons paint the Figma color, dark=$isDark',
        (tester) async {
      final expectedRgb = isDark ? 0xFFFFFF : 0x0A0A0A;
      final backgroundRgb = isDark ? 0x282929 : 0xFFFFFF;
      final boundaryKey = GlobalKey();
      for (var selection = 0; selection < 4; selection++) {
        await tester.pumpWidget(MaterialApp(
          theme: isDark ? app_style.darktheme : app_style.whitetheme,
          home: Scaffold(
            bottomNavigationBar: RepaintBoundary(
              key: boundaryKey,
              child: OneTouchBottomNavigationBar(
                currentIndex: selection,
                onTap: (_) {},
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final barRect =
            tester.getRect(find.byType(OneTouchBottomNavigationBar));
        final iconRects = List.generate(4, (index) {
          final item = find.byKey(ValueKey('main-bottom-navigation-$index'));
          return tester
              .getRect(find.descendant(
                of: item,
                matching: find.byType(SvgPicture),
              ))
              .shift(-barRect.topLeft);
        });

        // 위젯 속성이 같아도 SVG 마스크 때문에 실제 픽셀은 옅어질 수 있어요.
        await tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 3);
          final pixels =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          for (var index = 0; index < iconRects.length; index++) {
            final rect = iconRects[index];
            final counts = <int, int>{};
            for (var y = (rect.top * 3).ceil();
                y < (rect.bottom * 3).floor();
                y++) {
              for (var x = (rect.left * 3).ceil();
                  x < (rect.right * 3).floor();
                  x++) {
                final offset = (y * image.width + x) * 4;
                final rgb = (pixels.getUint8(offset) << 16) |
                    (pixels.getUint8(offset + 1) << 8) |
                    pixels.getUint8(offset + 2);
                if (rgb != backgroundRgb) {
                  counts.update(rgb, (n) => n + 1, ifAbsent: () => 1);
                }
              }
            }
            final dominant =
                counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
            expect(dominant, expectedRgb,
                reason: 'selection=$selection, icon=$index');
          }
          image.dispose();
        });
        final expectedColor = Color(0xFF000000 | expectedRgb);
        for (final text in tester.widgetList<Text>(find.descendant(
          of: find.byType(OneTouchBottomNavigationBar),
          matching: find.byType(Text),
        ))) {
          expect(text.style!.color, expectedColor);
        }
      }
    });
  }

  testWidgets('a bottom tab tap opens that branch root and announces it',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/players/42',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              MainScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Text('home-root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/team',
                  builder: (context, state) => const Text('team-root'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/players',
                  builder: (context, state) => const Text('players-root'),
                  routes: [
                    GoRoute(
                      path: ':id',
                      pageBuilder: (context, state) => NoTransitionPage<void>(
                        key: state.pageKey,
                        child: const Text('player-detail'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/community',
                  builder: (context, state) => const Text('community-root'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/players/42');

    final tabEvents = <String>[];
    void recordTabAction() {
      tabEvents.add(
        '${mainTabActions.tabIndex}:${router.routeInformationProvider.value.uri.path}',
      );
    }

    mainTabActions.addListener(recordTabAction);
    addTearDown(() => mainTabActions.removeListener(recordTabAction));

    await tester.tap(
      find.byKey(const ValueKey('main-bottom-navigation-3')),
    );
    expect(tabEvents.first, '3:/players/42');
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/community');
    expect(find.text('community-root'), findsOneWidget);
    await tester.pumpAndSettle();

    tabEvents.clear();
    await tester.tap(find.byKey(const ValueKey('main-bottom-navigation-2')));
    expect(tabEvents.first, '2:/community');
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/players');
    expect(find.text('players-root'), findsOneWidget);
    expect(find.text('player-detail'), findsNothing);
    await tester.pumpAndSettle();

    tabEvents.clear();
    await tester.tap(find.byKey(const ValueKey('main-bottom-navigation-0')));
    expect(tabEvents.first, '0:/players');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');

    tabEvents.clear();
    await tester.tap(
      find.byKey(const ValueKey('main-bottom-navigation-2')),
    );
    expect(tabEvents.first, '2:/home');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/players');
    expect(mainTabActions.tabIndex, 2);
    expect(find.text('players-root'), findsOneWidget);

    tabEvents.clear();
    await tester.tap(find.byKey(const ValueKey('main-bottom-navigation-2')));
    expect(tabEvents.first, '2:/players');
    await tester.pumpAndSettle();

    router.go('/team');
    await tester.pumpAndSettle();
    tabEvents.clear();
    await tester.tap(find.byKey(const ValueKey('main-bottom-navigation-3')));
    await tester.pumpAndSettle();
    expect(tabEvents.first, '3:/team');
    expect(router.routeInformationProvider.value.uri.path, '/community');

    tabEvents.clear();
    await tester.tap(find.byKey(const ValueKey('main-bottom-navigation-2')));
    await tester.pumpAndSettle();
    expect(tabEvents.first, '2:/community');
    expect(router.routeInformationProvider.value.uri.path, '/players');

    tabEvents.clear();
    await tester.tap(find.byKey(const ValueKey('main-bottom-navigation-0')));
    await tester.pumpAndSettle();
    expect(tabEvents.first, '0:/players');
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(tester.takeException(), isNull);
  });
}
