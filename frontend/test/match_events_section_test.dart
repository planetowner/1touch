import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/match_info/match_info_features.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
  });

  for (final width in [320.0, 393.0, 420.0, 430.0]) {
    testWidgets(
        'anchors names to the centered icon and fills minute rows at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final name in [
        'F.',
        'F. Valverde',
        'F. 발베르데',
        'Alexandros Papadopoulos'
      ]) {
        const minutes = ["20'", "27'", "42'", "45+2'", "90+7'"];
        await tester.pumpWidget(MaterialApp(
          theme: app_style.darktheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: MatchEventsSection(events: [
                for (final team in ['home', 'away'])
                  for (final minute in minutes)
                    (
                      playerId: null,
                      player: name,
                      minute: minute,
                      side: team == 'home'
                          ? MatchEventSide.home
                          : MatchEventSide.away,
                      type: MatchSummaryEventType.goal,
                    ),
                (
                  playerId: null,
                  player: name,
                  minute: "88'",
                  side: MatchEventSide.home,
                  type: MatchSummaryEventType.redCard,
                ),
              ]),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final icon = tester
            .getRect(find.byKey(const ValueKey('match-events-icon-goal')));
        expect(icon.center.dx, width / 2);
        expect(icon.size, const Size(20, 20));
        final card = tester
            .getRect(find.byKey(const ValueKey('match-events-icon-redCard')));
        expect(card.center.dx, width / 2);

        for (final team in ['home', 'away']) {
          final home = team == 'home';
          final row = find.byKey(ValueKey('match-event-$team-goal-$name'));
          final nameFinder =
              find.descendant(of: row, matching: find.text(name));
          final nameRect = tester.getRect(nameFinder);
          expect(home ? icon.left - nameRect.right : nameRect.left - icon.right,
              closeTo(8, 0.001));

          final minuteAreaFinder = find.descendant(
            of: row,
            matching: find.byKey(const ValueKey('match-event-minute-area')),
          );
          final minuteAreaRect = tester.getRect(minuteAreaFinder);
          expect(
              home
                  ? nameRect.left - minuteAreaRect.right
                  : minuteAreaRect.left - nameRect.right,
              closeTo(8, 0.001));
          expect(home ? minuteAreaRect.left : minuteAreaRect.right,
              home ? 24 : width - 24);

          final times = [
            for (var i = 0; i < minutes.length; i++)
              tester.getRect(find.descendant(
                  of: row,
                  matching: find.text(
                      '${minutes[i]}${i < minutes.length - 1 ? ',' : ''}'))),
          ];
          for (var i = 0; i < times.length; i++) {
            final time = times[i];
            expect(
                time.left, greaterThanOrEqualTo(minuteAreaRect.left - 0.001));
            expect(time.right, lessThanOrEqualTo(minuteAreaRect.right + 0.001));
            expect(time.height, times.first.height);
            if (i > 0 && time.top != times[i - 1].top) {
              final previousLine =
                  times.where((r) => r.top == times[i - 1].top);
              final previousWrapFinder = find.ancestor(
                of: find.descendant(
                  of: row,
                  matching: find.text(
                    '${minutes[i - 1]}${i - 1 < minutes.length - 1 ? ',' : ''}',
                  ),
                ),
                matching: find.byType(Wrap),
              );
              final spacing = tester.widget<Wrap>(previousWrapFinder).spacing;
              final usedWidth =
                  previousLine.fold(0.0, (sum, r) => sum + r.width) +
                      spacing * (previousLine.length - 1);
              // 다음 시각이 들어갈 공간이 없을 때만 줄을 바꿔요.
              expect(usedWidth + spacing + time.width,
                  greaterThan(minuteAreaRect.width));
            }
            final sameLine = times.where((r) => r.top == time.top).toList();
            final lineWrapFinder = find.ancestor(
              of: find.descendant(
                of: row,
                matching: find.text(
                  '${minutes[i]}${i < minutes.length - 1 ? ',' : ''}',
                ),
              ),
              matching: find.byType(Wrap),
            );
            final lineWrap = tester.widget<Wrap>(lineWrapFinder);
            expect(lineWrap.alignment, WrapAlignment.start);
            final lineTops = times.map((rect) => rect.top).toSet().toList()
              ..sort();
            final lineIndex = lineTops.indexOf(time.top);
            if (lineIndex == 0) {
              expect(
                home ? sameLine.first.left : sameLine.last.right,
                closeTo(
                    home ? minuteAreaRect.left : minuteAreaRect.right, 0.001),
              );
            } else {
              final firstLine =
                  times.where((rect) => rect.top == lineTops.first);
              final firstLeft = firstLine
                  .map((rect) => rect.left)
                  .reduce((a, b) => a < b ? a : b);
              final firstRight = firstLine
                  .map((rect) => rect.right)
                  .reduce((a, b) => a > b ? a : b);
              final currentLeft = sameLine
                  .map((rect) => rect.left)
                  .reduce((a, b) => a < b ? a : b);
              final currentRight = sameLine
                  .map((rect) => rect.right)
                  .reduce((a, b) => a > b ? a : b);
              final firstWidth = firstRight - firstLeft;
              final currentWidth = currentRight - currentLeft;
              final centeredLeft = (firstLeft + (firstWidth - currentWidth) / 2)
                  .clamp(
                      minuteAreaRect.left, minuteAreaRect.right - currentWidth);
              expect(currentLeft, closeTo(centeredLeft, 0.001));
            }
          }
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('centers a lone minute on the second wrapped line',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(350, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: MatchEventsSection(
              events: [
                (
                  playerId: null,
                  player: 'Valverde',
                  minute: "20'",
                  side: MatchEventSide.home,
                  type: MatchSummaryEventType.goal,
                ),
                (
                  playerId: null,
                  player: 'Valverde',
                  minute: "27'",
                  side: MatchEventSide.home,
                  type: MatchSummaryEventType.goal,
                ),
                (
                  playerId: null,
                  player: 'Valverde',
                  minute: "42'",
                  side: MatchEventSide.home,
                  type: MatchSummaryEventType.goal,
                ),
                (
                  playerId: null,
                  player: 'Vinicius',
                  minute: "55'",
                  side: MatchEventSide.home,
                  type: MatchSummaryEventType.goal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(
      const ValueKey('match-event-home-goal-Valverde'),
    );
    final minute20 = tester.getRect(
      find.descendant(of: row, matching: find.text("20',")),
    );
    final minute27 = tester.getRect(
      find.descendant(of: row, matching: find.text("27',")),
    );
    final minute42 = tester.getRect(
      find.descendant(of: row, matching: find.text("42'")),
    );

    expect(minute20.top, minute27.top);
    expect(minute42.top, greaterThan(minute20.top));
    expect(
      minute42.center.dx,
      closeTo((minute20.left + minute27.right) / 2, 0.001),
    );
    final viniciusRow = find.byKey(
      const ValueKey('match-event-home-goal-Vinicius'),
    );
    final viniciusTime = tester.getRect(
      find.descendant(of: viniciusRow, matching: find.text("55'")),
    );
    final viniciusArea = tester.getRect(
      find.descendant(
        of: viniciusRow,
        matching: find.byKey(const ValueKey('match-event-minute-area')),
      ),
    );
    expect(viniciusTime.left, closeTo(viniciusArea.left, 0.001));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
        'home and away events use compact independent columns at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MatchEventsSection(
              events: [
                (
                  playerId: null,
                  player: 'Rodrigo Muniz',
                  minute: "13'",
                  side: MatchEventSide.away,
                  type: MatchSummaryEventType.goal,
                ),
                (
                  playerId: null,
                  player: 'Morata',
                  minute: "16'",
                  side: MatchEventSide.home,
                  type: MatchSummaryEventType.goal,
                ),
                (
                  playerId: null,
                  player: 'Cesar Palacios',
                  minute: "37'",
                  side: MatchEventSide.away,
                  type: MatchSummaryEventType.goal,
                ),
                (
                  playerId: null,
                  player: 'Pablo',
                  minute: "45+2'",
                  side: MatchEventSide.home,
                  type: MatchSummaryEventType.goal,
                ),
                (
                  playerId: null,
                  player: 'Oscar Bobb',
                  minute: "78'",
                  side: MatchEventSide.away,
                  type: MatchSummaryEventType.goal,
                ),
              ],
            ),
          ),
        ),
      );

      final homeColumn = tester.widget<Column>(
        find.byKey(const ValueKey('match-events-home-goal')),
      );
      final awayColumn = tester.widget<Column>(
        find.byKey(const ValueKey('match-events-away-goal')),
      );
      final homeFirstY = tester.getTopLeft(find.text('Morata')).dy;
      final homeSecondY = tester.getTopLeft(find.text('Pablo')).dy;
      final awayFirstY = tester.getTopLeft(find.text('Rodrigo Muniz')).dy;
      final awaySecondY = tester.getTopLeft(find.text('Cesar Palacios')).dy;
      final awayThirdY = tester.getTopLeft(find.text('Oscar Bobb')).dy;

      expect(homeColumn.children.where((child) => child.key != null),
          hasLength(2));
      expect(awayColumn.children.where((child) => child.key != null),
          hasLength(3));
      expect(homeFirstY, awayFirstY);
      expect(homeSecondY, awaySecondY);
      expect(homeSecondY - homeFirstY, awaySecondY - awayFirstY);
      expect(awayThirdY - awaySecondY, awaySecondY - awayFirstY);
      expect(homeFirstY, 12);
      expect(homeSecondY - tester.getBottomLeft(find.text('Morata')).dy, 8);
      expect(tester.getBottomLeft(find.byType(MatchEventsSection)).dy,
          tester.getBottomLeft(find.text('Oscar Bobb')).dy);

      for (final event in [
        ('home', 'Morata', "16'"),
        ('home', 'Pablo', "45+2'"),
        ('away', 'Rodrigo Muniz', "13'"),
        ('away', 'Cesar Palacios', "37'"),
        ('away', 'Oscar Bobb', "78'"),
      ]) {
        final row = find.byKey(
          ValueKey('match-event-${event.$1}-goal-${event.$2}'),
        );
        final wrapFinder =
            find.descendant(of: row, matching: find.byType(Wrap));
        final minuteFinder =
            find.descendant(of: row, matching: find.text(event.$3));

        expect(tester.widget<Wrap>(wrapFinder).alignment, WrapAlignment.start);
        expect(
          tester.getRect(minuteFinder).left,
          closeTo(tester.getRect(wrapFinder).left, 0.001),
        );
        final minuteArea = tester.getRect(find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('match-event-minute-area')),
        ));
        expect(
          event.$1 == 'home'
              ? tester.getRect(minuteFinder).left
              : tester.getRect(minuteFinder).right,
          closeTo(
              event.$1 == 'home' ? minuteArea.left : minuteArea.right, 0.001),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
