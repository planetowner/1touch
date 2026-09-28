import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/KaneRest.dart';
import 'package:onetouch/features/player/player_following_controller.dart';

import 'support/player_directory_fixture.dart';

void main() {
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
            player: const PlayerMatchStatData(
              playerId: 2,
              teamId: 83,
              teamPrimaryColor: 0xFFA50044,
              name: 'Test Player',
              jerseyNumber: 7,
              positions: ['FW'],
              club: 'Barcelona',
              nationality: 'Korea Republic',
              sections: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
}
