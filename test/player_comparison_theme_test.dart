import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';

void main() {
  for (final testCase in <({
    String name,
    ThemeData theme,
    Color page,
    Color foreground,
    Color headerStart,
    Color headerEnd,
    Color imageSurface,
    Color detailsSurface,
    Color statSurface,
    Color sheetSurface,
    Color fieldSurface,
  })>[
    (
      name: 'light',
      theme: whitetheme,
      page: AppPalette.lightModeDarkGrey,
      foreground: AppPalette.black,
      headerStart: AppPalette.white,
      headerEnd: AppPalette.lightModeDarkGrey,
      imageSurface: AppPalette.lightGreyBox,
      detailsSurface: AppPalette.white,
      statSurface: AppPalette.white,
      sheetSurface: AppPalette.white,
      fieldSurface: AppPalette.lightGreyBox,
    ),
    (
      name: 'dark',
      theme: darktheme,
      page: const Color(0xFF0A0A0A),
      foreground: AppPalette.white,
      headerStart: Colors.black,
      headerEnd: AppPalette.darkGrey,
      imageSurface: AppPalette.darkGrey,
      detailsSurface: AppPalette.lightGrey,
      statSurface: const Color(0xFF1C1C1E),
      sheetSurface: const Color(0xFF1C1C1E),
      fieldSurface: const Color(0xFF2C2C2E),
    ),
  ]) {
    testWidgets(
      'comparison uses approved ${testCase.name} surfaces in all states',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: testCase.theme,
            home: const PlayerComparisonScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(
          find.byKey(const ValueKey('player-comparison-scaffold')),
        );
        expect(scaffold.backgroundColor, testCase.page);

        final header = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('comparison-header-gradient')),
        );
        final headerGradient =
            (header.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(
          headerGradient.colors,
          [testCase.headerStart, testCase.headerEnd],
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new)).color,
          testCase.foreground,
        );
        expect(
          tester.widget<Text>(find.text('MOST COMPARED')).style?.color,
          testCase.foreground,
        );
        expect(
          tester.widget<Text>(find.text('Scott McTominay')).style?.color,
          testCase.foreground,
        );
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(
                  const ValueKey(
                    'comparison-card-image-scott-mctominay-mohamed-salah',
                  ),
                ),
              )
              .color,
          testCase.imageSurface,
        );
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(
                  const ValueKey(
                    'comparison-card-details-scott-mctominay-mohamed-salah',
                  ),
                ),
              )
              .color,
          testCase.detailsSurface,
        );

        await tester.tap(find.text('PLAYER 1'));
        await tester.pumpAndSettle();

        final playerSheet = tester.widget<Container>(
          find.byKey(const ValueKey('comparison-player-picker-sheet')),
        );
        expect(
          (playerSheet.decoration as BoxDecoration).color,
          testCase.sheetSurface,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .decoration
              ?.fillColor,
          testCase.fieldSurface,
        );

        await tester.tap(
          find.descendant(
            of: find.byKey(
              const ValueKey('comparison-player-picker-sheet'),
            ),
            matching: find.text('Erling Haaland'),
          ),
        );
        await tester.pumpAndSettle();

        final seasonSheet = tester.widget<Container>(
          find.byKey(const ValueKey('comparison-season-picker-sheet')),
        );
        expect(
          (seasonSheet.decoration as BoxDecoration).color,
          testCase.sheetSurface,
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mohamed Salah').first);
        await tester.pumpAndSettle();

        final radar = tester.widget<RadarChart>(find.byType(RadarChart));
        expect(radar.labelColor, testCase.foreground);
        expect(
          radar.gridColor,
          testCase.foreground.withValues(alpha: 0.30),
        );
        expect(
          tester.widget<Text>(find.text('FINISH')).style?.color,
          testCase.foreground,
        );
        final statCard = tester.widget<Container>(
          find.byKey(const ValueKey('comparison-stat-card-FINISH')),
        );
        expect(
          (statCard.decoration as BoxDecoration).color,
          testCase.statSurface,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('comparison remains responsive at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: whitetheme, home: const PlayerComparisonScreen()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Mohamed Salah').first);
      await tester.pumpAndSettle();

      expect(find.byType(RadarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
