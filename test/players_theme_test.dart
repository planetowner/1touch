import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/screens/PlayerScreen.dart';

Color? _effectiveTextColor(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color;
}

BoxDecoration _decorationFor(WidgetTester tester, String key) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey(key)).first,
  );
  return container.decoration! as BoxDecoration;
}

void _usePhone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPlayers(
  WidgetTester tester, {
  required ThemeData theme,
  Size size = const Size(393, 852),
}) async {
  _usePhone(tester, size);
  await tester.pumpWidget(
    MaterialApp(theme: theme, home: const Players()),
  );
  await tester.pump();
}

void main() {
  for (final width in [320.0, 375.0, 393.0]) {
    testWidgets('Players light mode fits ${width}px', (tester) async {
      await _pumpPlayers(
        tester,
        theme: app_style.whitetheme,
        size: Size(width, width == 320 ? 568 : 852),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Players gradient extends responsively', (tester) async {
    await _pumpPlayers(
      tester,
      theme: app_style.whitetheme,
      size: const Size(393, 852),
    );

    final gradientFinder = find.byKey(const ValueKey('players-brand-gradient'));
    final gradientContainer = tester.widget<Container>(gradientFinder);
    final gradient = (gradientContainer.decoration! as BoxDecoration).gradient!
        as LinearGradient;

    expect(tester.getSize(gradientFinder).height, closeTo(596.4, 0.01));
    expect(gradient.stops, const [0.0, 0.65]);
    expect(tester.takeException(), isNull);
  });

  for (final testCase in <({
    String name,
    ThemeData theme,
    Color page,
    Color ranking,
    Color badge,
    Color pill,
    Color watchImage,
    Color watchInfo,
    Color foreground,
  })>[
    (
      name: 'light',
      theme: app_style.whitetheme,
      page: app_style.AppPalette.lightModeDarkGrey,
      ranking: app_style.AppPalette.white,
      badge: app_style.AppPalette.white,
      pill: app_style.AppPalette.lightGreyBox,
      watchImage: app_style.AppPalette.lightGreyBox,
      watchInfo: app_style.AppPalette.white,
      foreground: app_style.AppPalette.black,
    ),
    (
      name: 'dark',
      theme: app_style.darktheme,
      page: app_style.AppPalette.black,
      ranking: const Color(0xFF2A2A2A),
      badge: app_style.AppPalette.lightGrey,
      pill: app_style.AppPalette.lightGrey,
      watchImage: const Color(0xFF272828),
      watchInfo: app_style.AppPalette.lightGrey,
      foreground: app_style.AppPalette.white,
    ),
  ]) {
    testWidgets('Players surfaces follow the ${testCase.name} theme',
        (tester) async {
      await _pumpPlayers(tester, theme: testCase.theme);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        testCase.page,
      );
      expect(_decorationFor(tester, 'players-ranking-card').color,
          testCase.ranking);
      expect(_decorationFor(tester, 'favorite-player-number-badge').color,
          testCase.badge);
      expect(
        _decorationFor(tester, 'players-filter-pill-PREMIER LEAGUE').color,
        testCase.pill,
      );
      expect(
        tester
            .widget<Container>(
              find.byKey(const ValueKey('ones-to-watch-image-surface')).first,
            )
            .color,
        testCase.watchImage,
      );
      expect(
        tester
            .widget<Container>(
              find.byKey(const ValueKey('ones-to-watch-info-surface')).first,
            )
            .color,
        testCase.watchInfo,
      );
      expect(
        _effectiveTextColor(tester, find.text('1TOUCH RANKING')),
        testCase.foreground,
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.tune)).color,
          testCase.foreground);
      expect(tester.widget<Icon>(find.byIcon(Icons.search).first).color,
          app_style.AppPalette.white);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.safety_divider)).color,
        app_style.AppPalette.white,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.account_circle_outlined)).color,
        app_style.AppPalette.white,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Players light-mode sheets use light surfaces', (tester) async {
    await _pumpPlayers(tester, theme: app_style.whitetheme);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        app_style.AppPalette.white);
    expect(_effectiveTextColor(tester, find.text('Filter')),
        app_style.AppPalette.black);
    expect(tester.widget<Icon>(find.byIcon(Icons.check).first).color,
        app_style.AppPalette.black);
    final filterButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'UPDATE FILTER'),
    );
    expect(
      filterButton.style?.backgroundColor?.resolve({}),
      app_style.AppPalette.black,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.border_color));
    await tester.pumpAndSettle();
    expect(
      _decorationFor(tester, 'following-players-sheet').color,
      app_style.AppPalette.white,
    );
    expect(
      _decorationFor(tester, 'following-players-search').color,
      app_style.AppPalette.lightGreyBox,
    );
    expect(_effectiveTextColor(tester, find.text('Following Players')),
        app_style.AppPalette.black);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full ranking popup uses a white light-mode surface',
      (tester) async {
    await _pumpPlayers(tester, theme: app_style.whitetheme);

    await tester.ensureVisible(find.text('See All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Scaffold>(find.byKey(const ValueKey('full-ranking-sheet')))
          .backgroundColor,
      app_style.AppPalette.white,
    );
    expect(_effectiveTextColor(tester, find.text('1Touch Ranking')),
        app_style.AppPalette.black);
    expect(tester.takeException(), isNull);
  });
}
