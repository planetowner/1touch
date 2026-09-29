import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/features/KaneRest.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/l10n/football_name_labels.dart';

import 'support/player_directory_fixture.dart';
import 'support/player_detail_fixture.dart';

void main() {
  const player = PlayerMatchStatData(
    playerId: 2,
    teamId: 83,
    teamPrimaryColor: 0xFFA50044,
    name: 'Test Player',
    jerseyNumber: 7,
    positions: ['FW'],
    club: 'Barcelona',
    nationalityId: 712,
    nationality: 'Korea Republic',
    playerImageAsset: 'assets/playerAvatar.png',
    sections: [],
  );

  testWidgets('KaneRest light mode uses the reference surface and type scale',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: PlayerMatchStatSheet(player: mockRashfordStats),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<ColoredBox>(
      find
          .ancestor(
              of: find.byType(ListView), matching: find.byType(ColoredBox))
          .first,
    );
    expect(background.color, app_style.AppPalette.lightGreyBox);
    final header = tester.widget<Container>(
      find.byKey(const ValueKey('player-match-stat-header')),
    );
    final gradient =
        (header.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors.first, app_style.AppPalette.lightGreyBox);

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('match-player-stat-card')).first,
    );
    expect(
        (card.decoration as BoxDecoration).color, app_style.AppPalette.white);

    expect(tester.widget<Text>(find.text('M. Rashford')).style?.fontSize,
        Heading3.style.fontSize);
    expect(tester.widget<Text>(find.text('14')).style?.fontSize,
        Heading1.latinStyle.fontSize);
    expect(tester.widget<Text>(find.text('FINISH')).style?.fontSize,
        Body2_b.style.fontSize);
    expect(tester.widget<Text>(find.text('FINISH')).style?.fontWeight,
        Body2_b.style.fontWeight);
    expect(tester.widget<Text>(find.text('Goals')).style?.fontWeight,
        Body1_b.style.fontWeight);
    expect(tester.widget<Text>(find.text('1')).style?.fontWeight,
        Body1.style.fontWeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KaneRest star toggles the shared following state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeFollowingPlayersRepository();
    final controller = PlayerFollowingController(repository: repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        builder: (context, child) => FootballNamesScope(
          names: const FootballNames(countries: {712: '대한민국'}),
          child: child!,
        ),
        home: Scaffold(
          body: PlayerMatchStatSheet(
            followingController: controller,
            detailRepository: FakePlayerDetailRepository(),
            player: player,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final imageFade = tester.widget<ShaderMask>(
      find.byKey(const ValueKey('player-match-stat-image-bottom-fade')),
    );
    expect(imageFade.blendMode, BlendMode.dstIn);
    expect(find.text('대한민국'), findsOneWidget);

    final followButton = find.byKey(
      const ValueKey('player-match-stat-follow-button'),
    );
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);

    await tester.tap(followButton);
    await tester.pumpAndSettle();
    expect(repository.saved, [1, 2]);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);

    await tester.tap(followButton);
    await tester.pumpAndSettle();
    expect(repository.saved, [1]);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads and shows the player country below the team name',
      (tester) async {
    final detailRepository = FakePlayerDetailRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: PlayerMatchStatSheet(
            player: const PlayerMatchStatData(
              playerId: 2,
              teamPrimaryColor: 0xFFA50044,
              name: 'Test Player',
              jerseyNumber: 7,
              positions: ['FW'],
              club: 'Barcelona',
              nationality: null,
              sections: [],
            ),
            detailRepository: detailRepository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(detailRepository.calls, [(playerId: 2, seasonId: null)]);
    expect(find.text('South Korea'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Barcelona')).dy -
          tester.getBottomLeft(find.text('FW')).dy,
      8,
    );
    expect(
      tester.getTopLeft(find.text('South Korea')).dy -
          tester.getBottomLeft(find.text('Barcelona')).dy,
      8,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('player profile from match stats returns to its match',
      (tester) async {
    final controller = PlayerFollowingController(
      repository: FakeFollowingPlayersRepository(),
    );
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/match/55?status=past'),
              child: const Text('Open match'),
            ),
          ),
        ),
        GoRoute(
          path: '/match/:matchId',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => PlayerMatchStatSheet(
                  player: player,
                  followingController: controller,
                ),
              ),
              child: Text('Match ${state.pathParameters['matchId']}'),
            ),
          ),
        ),
        GoRoute(
          path: '/match-player/:playerId',
          builder: (_, state) => Scaffold(
            body: Text('Player ${state.pathParameters['playerId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match 55'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('player-match-stat-profile-link')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player 2'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Match 55'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Open match'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping above the KaneRest popup dismisses it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlayerMatchStatSheet(
                context,
                player,
                detailRepository: FakePlayerDetailRepository(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-match-stat-sheet')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(24, 48));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-match-stat-sheet')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
