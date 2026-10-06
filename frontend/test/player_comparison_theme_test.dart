import 'package:cached_network_image/cached_network_image.dart';
import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/screens/player_comparison_screen.dart';
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

class _SkewedStatsRepository extends FakePlayerDetailRepository {
  _SkewedStatsRepository(this.firstValue, this.secondValue);

  final double firstValue;
  final double secondValue;

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async {
    final json = playerDetailJson(playerId: playerId, seasonId: seasonId);
    final analysis = json['analysis'] as Map<String, dynamic>;
    final categories = analysis['categories'] as List<dynamic>;
    final finish = categories.first as Map<String, dynamic>;
    final goals =
        (finish['metrics'] as List<dynamic>).first as Map<String, dynamic>;
    goals['value'] = playerId == 1 ? firstValue : secondValue;
    return playerDetailFromJson(json);
  }
}

void main() {
  setUpAppCatalog();
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

    final image = tester.widget<CachedNetworkImage>(find.descendant(
      of: find.byKey(const ValueKey('comparison-header-network-photo-1')),
      matching: find.byType(CachedNetworkImage),
    ));
    expect(image.imageUrl, url);
    expect(image.cacheManager, isNotNull);
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
        expect(statCard.padding, const EdgeInsets.fromLTRB(24, 24, 24, 0));
        expect(decoration.borderRadius, BorderRadius.circular(16));
        expect(tester.widget<Text>(find.text('VS')).style?.fontSize, 18);
        expect(
          tester.getTopLeft(find.text('ATTRIBUTES')).dy -
              tester
                  .getRect(
                      find.byKey(const ValueKey('comparison-header-gradient')))
                  .bottom,
          closeTo(24, 0.1),
        );
        final categoryTitle = tester.widget<Text>(find.text('FINISH'));
        expect(categoryTitle.style?.fontSize, Body2_b.style.fontSize);
        expect(categoryTitle.style?.fontWeight, Body2_b.style.fontWeight);
        final statName = tester.widget<Text>(find.text('Goals'));
        expect(statName.style?.fontSize, Body1_b.style.fontSize);
        expect(statName.style?.fontWeight, Body1_b.style.fontWeight);
        expect(
          statName.style?.color,
          categoryTitle.style?.color,
        );
        final cardRect = tester
            .getRect(find.byKey(const ValueKey('comparison-stat-card-Finish')));
        final titleRect = tester.getRect(find.text('FINISH'));
        final goalRect = tester.getRect(find.text('Goals'));
        final goalBarRect = tester
            .getRect(find.byKey(const ValueKey('comparison-stat-first-goals')));
        final xgRect = tester.getRect(find.text('xG'));
        expect(cardRect.top - titleRect.bottom, closeTo(16, 0.1));
        expect(goalRect.left - cardRect.left, closeTo(24, 0.1));
        expect(goalRect.top - cardRect.top, closeTo(24, 0.1));
        expect(goalBarRect.top - goalRect.bottom, closeTo(12, 0.1));
        expect(goalBarRect.height, 32);
        expect(xgRect.top - goalBarRect.bottom, closeTo(24, 0.1));
        final statValue = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('comparison-stat-card-Finish')),
                matching: find.byType(Text),
              ),
            )
            .firstWhere((text) => text.data == '—');
        expect(statValue.style?.fontSize, Heading4.style.fontSize);
        expect(statValue.style?.fontWeight, Heading4.style.fontWeight);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final values in [(100.0, 1.0), (16.0, 0.0)]) {
    testWidgets('comparison keeps $values readable with 12px edge padding',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: PlayerComparisonScreen(
          initialPlayerId: '1',
          repository: _SkewedStatsRepository(values.$1, values.$2),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PLAYER 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Player 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('26/27'));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('comparison-stat-card-Finish'));
      final firstText = find.descendant(
        of: card,
        matching: find.text(values.$1.toInt().toString()),
      );
      final secondText = find.descendant(
        of: card,
        matching: find.text(values.$2.toInt().toString()),
      );
      final firstSegment =
          find.byKey(const ValueKey('comparison-stat-first-goals'));
      final secondSegment =
          find.byKey(const ValueKey('comparison-stat-second-goals'));
      expect(firstText, findsOneWidget);
      expect(secondText, findsOneWidget);
      expect(tester.widget<Text>(firstText).style?.fontSize,
          Heading4.style.fontSize);
      expect(tester.widget<Text>(secondText).style?.fontSize,
          Heading4.style.fontSize);
      expect(
        tester.getTopLeft(firstText).dx - tester.getTopLeft(firstSegment).dx,
        closeTo(12, 0.1),
      );
      expect(
        tester.getTopRight(secondSegment).dx -
            tester.getTopRight(secondText).dx,
        closeTo(12, 0.1),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
