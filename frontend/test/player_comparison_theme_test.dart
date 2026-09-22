import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';
import 'support/player_detail_fixture.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets('comparison respects theme and fits $size dark=$dark',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
            theme: dark ? darktheme : whitetheme,
            home: PlayerComparisonScreen(
                initialPlayerId: '1',
                repository: FakePlayerDetailRepository())));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PLAYER 2'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Player 3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('26/27'));
        await tester.pumpAndSettle();
        final header = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('comparison-header-gradient')));
        final gradient =
            (header.decoration as BoxDecoration).gradient! as LinearGradient;
        expect(
            gradient.colors,
            dark
                ? const [Color(0xFF000000), AppPalette.darkGrey]
                : const [AppPalette.white, AppPalette.lightModeDarkGrey]);
        final statCard = tester.widget<Container>(
            find.byKey(const ValueKey('comparison-stat-card-Finish')));
        final decoration = statCard.decoration as BoxDecoration;
        expect(decoration.color, dark ? AppPalette.darkGrey : AppPalette.white);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
