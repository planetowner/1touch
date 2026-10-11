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

  for (final dark in [true, false]) {
    for (final width in [320.0, 393.0]) {
      testWidgets(
          'switches substitutes and keeps full names left aligned at $width in ${dark ? 'dark' : 'light'} mode',
          (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? tappedPlayerId;
        await tester.pumpWidget(MaterialApp(
          theme: dark ? darktheme : whitetheme,
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
                  eventsByPlayer: const {
                    10: [
                      LineupEvent(type: LineupEventType.subIn, minute: 82),
                      LineupEvent(type: LineupEventType.goal, minute: 85),
                      LineupEvent(type: LineupEventType.yellowCard, minute: 88),
                    ],
                    11: [
                      LineupEvent(type: LineupEventType.subIn, minute: 73),
                    ],
                  },
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
        expect(find.text('10 $longHomeName'), findsOneWidget);
        expect(find.text('11 $longAwayName'), findsNothing);
        expect(find.text('Home Coach Full Name'), findsOneWidget);
        final homeName = find.text('10 $longHomeName');
        final homeNumber = (tester.widget<Text>(homeName).textSpan! as TextSpan)
            .children!
            .first as TextSpan;
        expect(homeNumber.text, '10 ');
        expect(homeNumber.style!.color,
            (dark ? Colors.white : Colors.black).withValues(alpha: 0.5));
        expect(tester.widget<Text>(homeName).maxLines, isNull);
        expect(tester.getRect(homeName).left, 24);
        expect(tester.getSize(homeName).height, greaterThan(24));
        expect(find.byType(MatchEventIcon), findsNWidgets(3));
        final homeIcons = tester
            .widgetList<MatchEventIcon>(find.byType(MatchEventIcon))
            .toList();
        expect(
            homeIcons
                .singleWhere((icon) => icon.type == LineupEventType.subIn)
                .size,
            20);
        expect(
            homeIcons
                .singleWhere((icon) => icon.type == LineupEventType.goal)
                .size,
            16);

        await tester
            .tap(find.byKey(const ValueKey('match-substitutes-away-toggle')));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<AppSegmentedToggle<bool>>(
                    find.byType(AppSegmentedToggle<bool>))
                .value,
            isFalse);
        expect(find.text('10 $longHomeName'), findsNothing);
        expect(find.text('11 $longAwayName'), findsOneWidget);
        expect(find.text('Away Coach Full Name'), findsOneWidget);
        final awayName = find.text('11 $longAwayName');
        final awayNumber = (tester.widget<Text>(awayName).textSpan! as TextSpan)
            .children!
            .first as TextSpan;
        expect(awayNumber.text, '11 ');
        expect(awayNumber.style!.color,
            (dark ? Colors.white : Colors.black).withValues(alpha: 0.5));
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

  testWidgets('orders substitute events and keeps both cards separate',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: darktheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SubstitutesAndCoach(
            homeCode: 'HOME',
            awayCode: 'AWAY',
            subsA: [
              Substitute(
                teamId: 1,
                playerId: 10,
                jerseyNumber: 9,
                name: 'First Last Name',
              ),
            ],
            subsB: const [],
            eventsByPlayer: const {
              10: [
                LineupEvent(type: LineupEventType.secondYellowCard, minute: 82),
                LineupEvent(type: LineupEventType.goal, minute: 61),
                LineupEvent(type: LineupEventType.injury, minute: 83),
                LineupEvent(type: LineupEventType.subOut, minute: 83),
                LineupEvent(type: LineupEventType.yellowCard, minute: 75),
                LineupEvent(type: LineupEventType.subIn, minute: 50),
                LineupEvent(type: LineupEventType.assist, minute: 70),
              ],
            },
            coachA: 'Coach',
            coachB: 'Coach',
          ),
        ),
      ),
    ));

    final row = find.byKey(const ValueKey('match-substitute-player-1-10'));
    final icons = tester
        .widgetList<MatchEventIcon>(
          find.descendant(of: row, matching: find.byType(MatchEventIcon)),
        )
        .toList();
    expect(icons.map((icon) => icon.type), [
      LineupEventType.subIn,
      LineupEventType.goal,
      LineupEventType.assist,
      LineupEventType.yellowCard,
      LineupEventType.secondYellowCard,
      LineupEventType.injury,
      LineupEventType.subOut,
    ]);
    expect(icons.first.size, 20);
    expect(icons.last.size, 20);
    expect(
        icons
            .where((icon) =>
                icon.type != LineupEventType.subIn &&
                icon.type != LineupEventType.subOut)
            .every((icon) => icon.size == 16),
        isTrue);
    expect(find.text("50'"), findsOneWidget);
    expect(find.text("83'"), findsOneWidget);
    final injury = find.byWidgetPredicate((widget) =>
        widget is MatchEventIcon && widget.type == LineupEventType.injury);
    final pitchOut = find.byWidgetPredicate((widget) =>
        widget is MatchEventIcon && widget.type == LineupEventType.subOut);
    expect(tester.getRect(injury).right,
        lessThanOrEqualTo(tester.getRect(pitchOut).left));
    final yellow = find.byWidgetPredicate((widget) =>
        widget is MatchEventIcon && widget.type == LineupEventType.yellowCard);
    final red = find.byWidgetPredicate((widget) =>
        widget is MatchEventIcon &&
        widget.type == LineupEventType.secondYellowCard);
    for (final (finder, fill) in [
      (yellow, const Color(0xFFFFCC00)),
      (red, const Color(0xFFFF5C5C)),
    ]) {
      final card = tester.widget<Container>(
        find.descendant(of: finder, matching: find.byType(Container)),
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(tester.getSize(find.byWidget(card)), const Size(8, 11));
      expect(decoration.color, fill);
      expect(decoration.borderRadius, BorderRadius.circular(1));
      expect(decoration.border!.top.color, const Color(0xFF3D3D3D));
      expect(decoration.border!.top.width, 1);
      expect(decoration.border!.top.strokeAlign, BorderSide.strokeAlignOutside);
    }
    expect(tester.getRect(yellow).overlaps(tester.getRect(red)), isFalse);
    expect(tester.takeException(), isNull);
  });
}
