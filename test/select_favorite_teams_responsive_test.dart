import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/RankFavTeams.dart';
import 'package:onetouch/Select_Favorite_Teams.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/teams/mock/team_catalog.dart';

void main() {
  const phoneSizes = [
    Size(320, 568),
    Size(375, 667),
    Size(393, 852),
  ];

  for (final size in phoneSizes) {
    testWidgets('fits a ${size.width}x${size.height} viewport', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.darktheme,
          home: const SelectFavoriteTeamsScreen(),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final testCase in <({ThemeData theme, Color background})>[
    (theme: app_style.darktheme, background: app_style.AppPalette.black),
    (theme: app_style.whitetheme, background: app_style.AppPalette.white),
  ]) {
    testWidgets('rank favorites uses a solid theme background', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: RankFavoriteTeamsScreen(
            selectedTeams: mockTeams.take(3).toList(),
          ),
        ),
      );
      await tester.pump();

      final backgroundFinder =
          find.byKey(const ValueKey('rank-favorites-background'));
      final background = tester.widget<ColoredBox>(backgroundFinder);
      expect(background.color, testCase.background);
      expect(tester.getTopLeft(backgroundFinder), Offset.zero);
      expect(tester.getSize(backgroundFinder), const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  }
}
