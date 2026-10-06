import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_segmented_toggle.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/models/match_data.dart';

void main() {
  const longHomeName = 'Alexander Christopher Maximilian Long Substitute Name';
  const longAwayName =
      'Benjamin Francisco Alejandro Very Long Away Player Name';

  for (final width in [320.0, 393.0]) {
    testWidgets(
        'switches substitutes and keeps full names left aligned at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? tappedPlayerId;
      await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SubstitutesAndCoach(
                homeCode: 'HOME',
                awayCode: 'AWAY',
                subsA: [
                  Substitute(
                    teamId: 1,
                    playerId: 10,
                    jerseyNumber: 10,
                    name: longHomeName,
                    minute: 82,
                    subIn: true,
                    goal: true,
                  ),
                ],
                subsB: [
                  Substitute(
                    teamId: 2,
                    playerId: 11,
                    jerseyNumber: 11,
                    name: longAwayName,
                    minute: 73,
                    subIn: true,
                  ),
                ],
                coachA: 'Home Coach Full Name',
                coachB: 'Away Coach Full Name',
                onPlayerTap: (_, player) => tappedPlayerId = player.playerId,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final toggle =
          find.byKey(const ValueKey('match-substitutes-team-toggle'));
      expect(
          tester
              .widget<AppSegmentedToggle<bool>>(
                  find.byType(AppSegmentedToggle<bool>))
              .value,
          isTrue);
      expect(tester.getSize(toggle).width, width - 48);
      expect(find.text('#10 $longHomeName'), findsOneWidget);
      expect(find.text('#11 $longAwayName'), findsNothing);
      expect(find.text('Home Coach Full Name'), findsOneWidget);
      final homeName = find.text('#10 $longHomeName');
      expect(tester.widget<Text>(homeName).maxLines, isNull);
      expect(tester.getRect(homeName).left, 24);
      expect(tester.getSize(homeName).height, greaterThan(24));
      expect(find.byType(MatchEventIcon), findsNWidgets(2));

      await tester
          .tap(find.byKey(const ValueKey('match-substitutes-away-toggle')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<AppSegmentedToggle<bool>>(
                  find.byType(AppSegmentedToggle<bool>))
              .value,
          isFalse);
      expect(find.text('#10 $longHomeName'), findsNothing);
      expect(find.text('#11 $longAwayName'), findsOneWidget);
      expect(find.text('Away Coach Full Name'), findsOneWidget);
      final awayName = find.text('#11 $longAwayName');
      expect(tester.getRect(awayName).left, 24);
      expect(tester.getSize(awayName).height, greaterThan(24));
      final awayRow =
          find.byKey(const ValueKey('match-substitute-player-2-11'));
      await tester.tap(awayRow);
      expect(tappedPlayerId, 11);
      expect(tester.takeException(), isNull);
    });
  }
}
