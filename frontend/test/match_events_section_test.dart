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
                    {
                      'player': name,
                      'minute': minute,
                      'team': team,
                      'type': 'goal'
                    },
                {
                  'player': name,
                  'minute': "88'",
                  'team': 'home',
                  'type': 'redCard'
                },
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
              closeTo(14.5, 0.001));

          final wrapFinder =
              find.descendant(of: row, matching: find.byType(Wrap));
          final wrapRect = tester.getRect(wrapFinder);
          final wrap = tester.widget<Wrap>(wrapFinder);
          expect(
              home
                  ? nameRect.left - wrapRect.right
                  : wrapRect.left - nameRect.right,
              closeTo(8, 0.001));
          expect(home ? wrapRect.left : wrapRect.right, home ? 24 : width - 24);

          final times = [
            for (var i = 0; i < minutes.length; i++)
              tester.getRect(find.descendant(
                  of: row,
                  matching: find.text(
                      '${minutes[i]}${i < minutes.length - 1 ? ',' : ''}'))),
          ];
          for (var i = 0; i < times.length; i++) {
            final time = times[i];
            expect(time.left, greaterThanOrEqualTo(wrapRect.left - 0.001));
            expect(time.right, lessThanOrEqualTo(wrapRect.right + 0.001));
            expect(time.height, times.first.height);
            if (i > 0 && time.top != times[i - 1].top) {
              final previousLine =
                  times.where((r) => r.top == times[i - 1].top);
              final usedWidth =
                  previousLine.fold(0.0, (sum, r) => sum + r.width) +
                      wrap.spacing * (previousLine.length - 1);
              // 다음 시각이 들어갈 공간이 없을 때만 줄을 바꿔요.
              expect(usedWidth + wrap.spacing + time.width,
                  greaterThan(wrapRect.width));
            }
            final sameLine = times.where((r) => r.top == time.top).toList();
            expect(home ? sameLine.first.left : sameLine.last.right,
                closeTo(home ? wrapRect.left : wrapRect.right, 0.001));
          }
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

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
                {
                  'player': 'Rodrigo Muniz',
                  'minute': "13'",
                  'team': 'away',
                  'type': 'goal',
                },
                {
                  'player': 'Morata',
                  'minute': "16'",
                  'team': 'home',
                  'type': 'goal',
                },
                {
                  'player': 'Cesar Palacios',
                  'minute': "37'",
                  'team': 'away',
                  'type': 'goal',
                },
                {
                  'player': 'Pablo',
                  'minute': "45+2'",
                  'team': 'home',
                  'type': 'goal',
                },
                {
                  'player': 'Oscar Bobb',
                  'minute': "78'",
                  'team': 'away',
                  'type': 'goal',
                },
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
      expect(tester.takeException(), isNull);
    });
  }
}
