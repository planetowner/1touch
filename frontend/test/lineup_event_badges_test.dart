import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('shows only the lineup header at ${width}px width',
        (tester) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LineupPitch(
              awayRows: [],
              homeRows: [],
              homeColor: Color(0xFFD92455),
              awayColor: Color(0xFF18539F),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final header = find.text('LINEUP');
      expect(header, findsOneWidget);
      expect(tester.getRect(header).left, 0);
      expect(find.textContaining('HOME'), findsNothing);
      expect(find.textContaining('AWAY'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final count in [5, 6]) {
    testWidgets('fits $count lineup players in a 319px row', (tester) async {
      tester.view.physicalSize = const Size(327, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LineupPitch(
              awayRows: const [],
              homeRows: [
                [
                  for (var index = 0; index < count; index++)
                    LineupPlayer(
                      teamId: 83,
                      playerId: index + 1,
                      number: index + 1,
                      name: 'Player ${index + 1}',
                    ),
                ],
              ],
              homeColor: const Color(0xFFD92455),
              awayColor: const Color(0xFF18539F),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final card =
          tester.getRect(find.byKey(const ValueKey('match-lineup-card')));
      for (var index = 0; index < count; index++) {
        final player = tester.getRect(find.byKey(
          ValueKey('match-lineup-player-83-${index + 1}'),
        ));
        expect(player.width, lessThanOrEqualTo(card.width / count + 0.001));
        expect(player.left, greaterThanOrEqualTo(card.left - 0.001));
        expect(player.right, lessThanOrEqualTo(card.right + 0.001));
      }
      expect(tester.takeException(), isNull);
    });
  }

  Widget subject(
    List<LineupEvent> events, {
    Color homeColor = const Color(0xFFD92455),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LineupPitch(
            awayRows: const [],
            homeColor: homeColor,
            awayColor: const Color(0xFF18539F),
            homeRows: [
              [
                LineupPlayer(
                  teamId: 83,
                  playerId: 1,
                  number: 10,
                  name: 'Yamal',
                  events: events,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('uses accessible jersey text on a mid-tone team color',
      (tester) async {
    await tester.pumpWidget(
      subject(const [], homeColor: const Color(0xFF777777)),
    );

    final circle = find.byKey(const ValueKey('lineup-player-circle'));
    final number = tester.widget<Text>(
      find.descendant(of: circle, matching: find.text('10')),
    );
    expect(number.style?.color, Colors.black);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlaps repeated event badges', (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.assist, minute: 20),
        LineupEvent(type: LineupEventType.assist, minute: 40),
      ]),
    );

    final stack = tester.widget<SizedBox>(
      find.byKey(const ValueKey('lineup-event-badge-groups')),
    );
    expect(stack.width, 25);
    expect(
      find.byKey(const ValueKey('lineup-event-assist-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('lineup-event-assist-1')),
      findsOneWidget,
    );
    expect(find.text("20'"), findsNothing);
    expect(find.text("40'"), findsNothing);
  });

  testWidgets('shows time only for pitch-in and pitch-out events',
      (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.goal, minute: 15),
        LineupEvent(type: LineupEventType.subIn, minute: 30),
        LineupEvent(type: LineupEventType.subOut, minute: 75),
      ]),
    );

    expect(find.text("15'"), findsNothing);
    expect(find.text("30'"), findsOneWidget);
    expect(find.text("75'"), findsOneWidget);
    expect(tester.widget<Text>(find.text("30'")).style!.fontSize, 12);
    expect(tester.widget<Text>(find.text("75'")).style!.fontSize, 12);
  });

  testWidgets('places pitch-out at the bottom right of the player circle',
      (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.subOut, minute: 75),
      ]),
    );

    final circle = find.byKey(const ValueKey('lineup-player-circle'));
    final pitchOut = find.byKey(const ValueKey('lineup-pitch-out-badge'));
    final circleRect = tester.getRect(circle);
    final pitchOutRect = tester.getRect(pitchOut);
    expect(pitchOutRect.center.dx, greaterThan(circleRect.center.dx));
    expect(pitchOutRect.center.dy, greaterThan(circleRect.center.dy));
    expect(pitchOutRect.left, circleRect.left + 20);
    expect(pitchOutRect.top, circleRect.top + 17);
    expect(tester.getRect(find.text('Yamal')).top - pitchOutRect.bottom, 1);
    final icon = find.byKey(const ValueKey('lineup-sub-out-icon'));
    final time = find.text("75'");
    expect(tester.getRect(time).left - tester.getRect(icon).right, 3);
    expect(tester.getRect(icon).top, lessThan(circleRect.bottom));
  });

  testWidgets('renders the updated event icon set', (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.assist),
        LineupEvent(type: LineupEventType.subIn),
        LineupEvent(type: LineupEventType.subOut),
        LineupEvent(type: LineupEventType.injury),
        LineupEvent(type: LineupEventType.yellowCard),
      ]),
    );

    expect(find.byKey(const ValueKey('lineup-goal-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-assist-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-sub-in-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-sub-out-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-injury-icon')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('lineup-goal-icon'))),
      const Size.square(16),
    );
    expect(
      find.byKey(const ValueKey('lineup-event-icon-outline')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lineup-sub-in-icon')),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lineup-sub-out-icon')),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('lineup-sub-in-icon'))),
      const Size.square(18),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('lineup-sub-out-icon'))),
      const Size.square(18),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('lineup-injury-icon'))),
      const Size.square(18),
    );
    final yellowCardIcon = tester
        .widgetList<MatchEventIcon>(find.byType(MatchEventIcon))
        .singleWhere((icon) => icon.type == LineupEventType.yellowCard);
    expect(yellowCardIcon.outlined, isTrue);
    final yellowCard = tester
        .widgetList<Container>(find.byType(Container))
        .singleWhere((container) {
      final decoration = container.decoration;
      return decoration is BoxDecoration &&
          decoration.color == const Color(0xFFFFCC00);
    });
    final cardDecoration = yellowCard.decoration! as BoxDecoration;
    expect(tester.getSize(find.byWidget(yellowCard)), const Size(8, 11));
    expect(cardDecoration.shape, BoxShape.rectangle);
    expect(cardDecoration.border!.top.color, Colors.black);
    expect(cardDecoration.border!.top.width, 1);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('places goal and assist at the bottom left', (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.assist, minute: 20),
        LineupEvent(type: LineupEventType.assist, minute: 40),
      ]),
    );

    final circle = find.byKey(const ValueKey('lineup-player-circle'));
    final badges = find.byKey(const ValueKey('lineup-scoring-badges'));
    expect(tester.getCenter(badges).dx, lessThan(tester.getCenter(circle).dx));
    expect(
      tester.getBottomLeft(badges).dy,
      tester.getBottomLeft(circle).dy + 3,
    );
    expect(
        tester.getRect(find.text('Yamal')).top -
            tester.getBottomLeft(badges).dy,
        1);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('centers the injury and pitch-out overlap at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.subOut, minute: 82),
      ]));
      final single =
          tester.getRect(find.byKey(const ValueKey('lineup-sub-out-icon')));

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.injury, minute: 82),
        LineupEvent(type: LineupEventType.subOut, minute: 82),
      ]));
      final injury =
          tester.getRect(find.byKey(const ValueKey('lineup-injury-icon')));
      final pitchOut =
          tester.getRect(find.byKey(const ValueKey('lineup-sub-out-icon')));
      final group = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey('lineup-pitch-out-badge')),
        matching: find.byKey(const ValueKey('lineup-event-badge-groups')),
      ));
      expect(group.center.dx, closeTo(single.center.dx, 0.01));
      expect(injury.left, lessThan(single.left));
      expect(pitchOut.right, greaterThan(single.right));
      expect(injury.overlaps(pitchOut), isTrue);
      expect(injury.left, lessThan(pitchOut.left));
      expect(injury.top, pitchOut.top);
      expect(injury.bottom, pitchOut.bottom);
      expect(tester.getRect(find.text('Yamal')).top - group.bottom, 1);
      expect(find.text("82'"), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.assist),
        LineupEvent(type: LineupEventType.injury, minute: 82),
        LineupEvent(type: LineupEventType.subOut, minute: 82),
      ]));
      final scoring =
          tester.getRect(find.byKey(const ValueKey('lineup-scoring-badges')));
      final overlappedOut =
          tester.getRect(find.byKey(const ValueKey('lineup-injury-icon')));
      expect(scoring.right, lessThan(overlappedOut.left));
      expect(tester.takeException(), isNull);
    });

    testWidgets('centers scoring badges and clears the pitch-out icon at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.goal),
      ]));
      final single =
          tester.getRect(find.byKey(const ValueKey('lineup-scoring-badges')));

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.assist),
      ]));
      final pair =
          tester.getRect(find.byKey(const ValueKey('lineup-scoring-badges')));
      expect(pair.center.dx, closeTo(single.center.dx, 0.01));
      expect(pair.left, lessThan(single.left));
      expect(pair.right, greaterThan(single.right));

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.assist),
      ]));
      final four =
          tester.getRect(find.byKey(const ValueKey('lineup-scoring-badges')));
      expect(four.center.dx, closeTo(single.center.dx, 0.01));
      expect(four.left, lessThan(pair.left));
      expect(four.right, greaterThan(pair.right));

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.assist),
        LineupEvent(type: LineupEventType.subOut, minute: 82),
      ]));
      final scoring =
          tester.getRect(find.byKey(const ValueKey('lineup-scoring-badges')));
      final pitchOut =
          tester.getRect(find.byKey(const ValueKey('lineup-sub-out-icon')));
      expect(pitchOut.bottom, scoring.bottom);
      expect(scoring.height, 16);
      expect(pitchOut.height, 18);
      expect(scoring.right, lessThan(pitchOut.left));
      expect(find.text("82'"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('centers overlapping yellow and red cards at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.yellowCard),
      ]));
      final single =
          tester.getRect(find.byKey(const ValueKey('lineup-card-badges')));
      final singleArtwork = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey('lineup-event-yellowCard-0')),
        matching: find.byType(Container),
      ));

      await tester.pumpWidget(subject(const [
        LineupEvent(type: LineupEventType.yellowCard, minute: 30),
        LineupEvent(type: LineupEventType.secondYellowCard, minute: 70),
      ]));
      final pair =
          tester.getRect(find.byKey(const ValueKey('lineup-card-badges')));
      final yellow = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey('lineup-event-yellowCard-0')),
        matching: find.byType(Container),
      ));
      final red = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey('lineup-event-redCard-1')),
        matching: find.byType(Container),
      ));
      expect(pair.center.dx, closeTo(single.center.dx, 0.01));
      expect(pair.left, lessThan(single.left));
      expect(pair.right, greaterThan(single.right));
      expect(yellow.center.dx, lessThan(singleArtwork.center.dx));
      expect(red.center.dx, greaterThan(singleArtwork.center.dx));
      expect(yellow.overlaps(red), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps cards top left and injury bottom right', (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.yellowCard),
        LineupEvent(type: LineupEventType.injury),
      ]),
    );

    final circle =
        tester.getRect(find.byKey(const ValueKey('lineup-player-circle')));
    final card =
        tester.getRect(find.byKey(const ValueKey('lineup-card-badges')));
    final injury =
        tester.getRect(find.byKey(const ValueKey('lineup-injury-icon')));
    expect(card.center.dx, lessThan(circle.center.dx));
    expect(card.center.dy, lessThan(circle.center.dy));
    expect(injury.center.dx, greaterThan(circle.center.dx));
    expect(injury.center.dy, greaterThan(circle.center.dy));
  });

  testWidgets('overlaps all badges with matching categories adjacent',
      (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.assist, minute: 20),
        LineupEvent(type: LineupEventType.goal, minute: 40),
        LineupEvent(type: LineupEventType.assist, minute: 60),
      ]),
    );

    final stack = tester.widget<SizedBox>(
      find.byKey(const ValueKey('lineup-event-badge-groups')),
    );
    expect(stack.width, 34);
    expect(find.byKey(const ValueKey('lineup-event-assist-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-event-assist-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-event-goal-2')), findsOneWidget);
  });

  testWidgets('shows a red card over a yellow for a second-yellow dismissal',
      (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.yellowCard, minute: 30),
        LineupEvent(type: LineupEventType.secondYellowCard, minute: 70),
      ]),
    );

    expect(
      find.byKey(const ValueKey('lineup-event-yellowCard-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('lineup-event-redCard-1')),
      findsOneWidget,
    );
  });

  testWidgets('shows stacked yellow and red from one yellowredcard event',
      (tester) async {
    await tester.pumpWidget(subject(const [
      LineupEvent(type: LineupEventType.secondYellowCard, minute: 70),
    ]));

    final yellow = tester.getRect(find.descendant(
      of: find.byKey(const ValueKey('lineup-event-yellowCard-0')),
      matching: find.byType(Container),
    ));
    final red = tester.getRect(find.descendant(
      of: find.byKey(const ValueKey('lineup-event-redCard-1')),
      matching: find.byType(Container),
    ));
    expect(yellow.overlaps(red), isTrue);
    expect(red.left, greaterThan(yellow.left));
  });

  testWidgets('does not infer a dismissal from two yellow events',
      (tester) async {
    await tester.pumpWidget(subject(const [
      LineupEvent(type: LineupEventType.yellowCard, minute: 30),
      LineupEvent(type: LineupEventType.yellowCard, minute: 70),
    ]));

    expect(find.byKey(const ValueKey('lineup-event-yellowCard-0')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-event-yellowCard-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-event-redCard-1')), findsNothing);
  });

  testWidgets('shows only one card badge for a direct red', (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.yellowCard, minute: 30),
        LineupEvent(type: LineupEventType.redCard, minute: 70),
      ]),
    );

    expect(
        find.byKey(const ValueKey('lineup-event-yellowCard-0')), findsNothing);
    expect(
      find.byKey(const ValueKey('lineup-event-redCard-0')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the pitch size for long Korean player names',
      (tester) async {
    tester.view.physicalSize = const Size(345, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previousLocale = appLocaleController.value;
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = previousLocale);

    List<List<LineupPlayer>> rows(int teamId) => [
          for (var index = 0; index < 5; index++)
            [
              LineupPlayer(
                teamId: teamId,
                playerId: teamId * 100 + index,
                number: index + 1,
                name: '아주긴한국어선수이름',
              ),
            ],
        ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: LineupPitch(
              awayRows: rows(2),
              homeRows: rows(1),
              homeColor: const Color(0xFFD92455),
              awayColor: const Color(0xFF18539F),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('match-lineup-card'))).height,
      784,
    );
    expect(tester.takeException(), isNull);
  });
}
