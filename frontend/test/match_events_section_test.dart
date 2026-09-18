import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';

void main() {
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

      expect(homeColumn.children, hasLength(2));
      expect(awayColumn.children, hasLength(3));
      expect(homeFirstY, awayFirstY);
      expect(homeSecondY, awaySecondY);
      expect(homeSecondY - homeFirstY, awaySecondY - awayFirstY);
      expect(awayThirdY - awaySecondY, awaySecondY - awayFirstY);
      expect(tester.takeException(), isNull);
    });
  }
}
