import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/KaneRest.dart';
import 'package:onetouch/features/player/player_following_controller.dart';

import 'support/player_directory_fixture.dart';

void main() {
  const player = PlayerMatchStatData(
    playerId: 2,
    teamId: 83,
    teamPrimaryColor: 0xFFA50044,
    name: 'Test Player',
    jerseyNumber: 7,
    positions: ['FW'],
    club: 'Barcelona',
    nationality: 'Korea Republic',
    playerImageAsset: 'assets/playerAvatar.png',
    sections: [],
  );

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
        home: Scaffold(
          body: PlayerMatchStatSheet(
            followingController: controller,
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

  testWidgets('tapping above the KaneRest popup dismisses it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPlayerMatchStatSheet(context, player),
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
