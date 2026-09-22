import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/screens/PlayerComparisonScreen.dart';
import 'support/player_detail_fixture.dart';

class _ImagePlayerDetailRepository extends FakePlayerDetailRepository {
  _ImagePlayerDetailRepository(this.image);
  final String image;

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async {
    calls.add((playerId: playerId, seasonId: seasonId));
    return detailFixture(
      playerId: playerId,
      seasonId: seasonId,
      position: playerId == 2 ? 'GK' : 'FW',
      playerImage: image,
    );
  }
}

void main() {
  testWidgets('empty comparison slots use the comparison placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home:
            PlayerComparisonScreen(repository: FakePlayerDetailRepository())));
    await tester.pumpAndSettle();

    for (final slot in [1, 2]) {
      final image = tester.widget<Image>(
          find.byKey(ValueKey('comparison-header-placeholder-$slot')));
      expect((image.image as AssetImage).assetName,
          'assets/player_comparison/player_placeholder.png');
    }
  });

  testWidgets('null API image uses the comparison placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1', repository: FakePlayerDetailRepository())));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('comparison-header-placeholder-1')),
        findsOneWidget);
  });

  testWidgets('API image URL takes priority over the placeholder',
      (tester) async {
    const url = 'https://cdn.example/player.png';
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1',
            repository: _ImagePlayerDetailRepository(url))));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
        find.byKey(const ValueKey('comparison-header-network-photo-1')));
    expect((image.image as NetworkImage).url, url);
  });

  testWidgets('failed API image falls back to the comparison placeholder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
            initialPlayerId: '1',
            repository:
                _ImagePlayerDetailRepository('https://invalid.test/x.png'))));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('comparison-header-placeholder-1')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
