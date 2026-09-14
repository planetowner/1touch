import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';

void main() {
  Widget subject(List<LineupEvent> events) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LineupPitch(
            awayRows: const [],
            homeRows: [
              [LineupPlayer(number: 10, name: 'Yamal', events: events)],
            ],
          ),
        ),
      ),
    );
  }

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
    expect(stack.width, 19);
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
  });

  testWidgets('places pitch-out at the top right of the player circle',
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
    expect(pitchOutRect.center.dy, lessThan(circleRect.center.dy));
    expect(pitchOutRect.left, lessThan(circleRect.right));
    expect(pitchOutRect.bottom, greaterThan(circleRect.top));
    final icon = find.byKey(const ValueKey('lineup-sub-out-icon'));
    final time = find.text("75'");
    expect(tester.getRect(time).left - tester.getRect(icon).right, 3);
  });

  testWidgets('renders the updated event icon set', (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.goal),
        LineupEvent(type: LineupEventType.assist),
        LineupEvent(type: LineupEventType.subIn),
        LineupEvent(type: LineupEventType.subOut),
        LineupEvent(type: LineupEventType.injury),
      ]),
    );

    expect(find.byKey(const ValueKey('lineup-goal-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-assist-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-sub-in-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-sub-out-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('lineup-injury-icon')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('centers event badges beneath the player circle', (tester) async {
    await tester.pumpWidget(
      subject(const [
        LineupEvent(type: LineupEventType.assist, minute: 20),
        LineupEvent(type: LineupEventType.assist, minute: 40),
      ]),
    );

    final circle = find.byKey(const ValueKey('lineup-player-circle'));
    final badges = find.byKey(const ValueKey('lineup-event-badge-groups'));
    expect(tester.getCenter(badges).dx, tester.getCenter(circle).dx);
    expect(
      tester.getBottomLeft(badges).dy,
      greaterThan(tester.getBottomLeft(circle).dy),
    );
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
    expect(stack.width, 26);
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
}
