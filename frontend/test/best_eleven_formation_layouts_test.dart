import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/formation_layout.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/models/team_best_eleven.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  test('formations put every player on symmetric, evenly spaced rows', () {
    for (final formation in [
      '4-3-3',
      '4-2-3-1',
      '3-5-2',
      '5-4-1',
      '2-2-2-2-2',
    ]) {
      final counts =
          formationLayoutCode(formation).split('-').map(int.parse).toList();
      final layout = FormationLayout.forFormation(formation);
      final centerX = FormationLayout.designSize.width / 2;
      expect(counts.reduce((a, b) => a + b), 10, reason: formation);
      expect(layout.positionForSlot('1:1')!.dx, centerX);
      final rowYs = <double>[FormationLayout.goalkeeper.dy];

      for (var row = 0; row < counts.length; row++) {
        final rowNumber = row + 2;
        final positions = [
          for (var column = 1; column <= counts[row]; column++)
            layout.positionForSlot('$rowNumber:$column')!,
        ];
        rowYs.add(
          positions.map((position) => position.dy).reduce((a, b) => a + b) /
              positions.length,
        );
        for (var column = 0; column < positions.length; column++) {
          final opposite = positions[positions.length - column - 1];
          expect(
              positions[column].dx + opposite.dx, closeTo(2 * centerX, 0.001),
              reason: '$formation row $rowNumber');
          expect(positions[column].dy, opposite.dy);
          if (column > 1) {
            expect(
              positions[column].dx - positions[column - 1].dx,
              closeTo(positions[1].dx - positions[0].dx, 0.001),
            );
          }
        }
      }
      for (var row = 1; row < rowYs.length; row++) {
        expect(rowYs[row], lessThan(rowYs[row - 1]));
      }
    }
  });

  test('defense, attack, and five-player midfield retain curved shapes', () {
    final threeForwards = FormationLayout.forFormation('4-1-2-3');
    expect(
      threeForwards.positionForSlot('2:1')!.dy,
      lessThan(threeForwards.positionForSlot('2:2')!.dy),
    );
    expect(
      threeForwards.positionForSlot('5:1')!.dy,
      greaterThan(threeForwards.positionForSlot('5:2')!.dy),
    );

    final fourMidfielders = FormationLayout.forFormation('4-4-2');
    expect(
      fourMidfielders.positionForSlot('3:1')!.dy,
      lessThan(fourMidfielders.positionForSlot('3:2')!.dy),
    );

    final fiveMidfielders = FormationLayout.forFormation('3-5-2');
    expect(
      fiveMidfielders.positionForSlot('3:2')!.dy,
      greaterThan(fiveMidfielders.positionForSlot('3:3')!.dy),
    );
    expect(
      fiveMidfielders.positionForSlot('3:4')!.dy,
      fiveMidfielders.positionForSlot('3:2')!.dy,
    );
  });

  test('4-3-3 uses the 4-1-2-3 shape without changing slot mapping', () {
    expect(formationLayoutCode('4-3-3'), '4-1-2-3');
    expect(formationLayoutCode('433'), '4-1-2-3');
    expect(formationLayoutCode('4-1-2-3'), '4-1-2-3');
    expect(formationLayoutSlotKey('4-3-3', '3:1'), '4:1');
    expect(formationLayoutSlotKey('4-3-3', '3:2'), '3:1');
    expect(formationLayoutSlotKey('4-3-3', '3:3'), '4:2');
    expect(formationLayoutSlotKey('4-3-3', '4:2'), '5:2');
  });

  test('keeps slots for other or missing formations unchanged', () {
    for (final formation in [null, '4-1-2-3', '4-2-3-1']) {
      for (final slot in ['1:1', '2:4', '3:1', '3:2', '4:1', '5:3']) {
        expect(formationLayoutSlotKey(formation, slot), slot);
      }
    }
  });

  test('invalid formations use a complete 4-1-2-3 layout', () {
    final layout = FormationLayout.forFormation('invalid');

    expect(layout.positionForSlot('1:1'), isNotNull);
    for (final (row, count) in [4, 1, 2, 3].indexed) {
      final rowNumber = row + 2;
      for (var column = 1; column <= count; column++) {
        expect(layout.positionForSlot('$rowNumber:$column'), isNotNull);
      }
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('pitch centers and mirrors player circles at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const slots = [
        '1:1',
        '2:1',
        '2:2',
        '2:3',
        '2:4',
        '3:1',
        '3:2',
        '3:3',
        '4:1',
        '4:2',
        '4:3',
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: BestElevenPitch(
                teamId: 503,
                formation: '4-3-3',
                players: [
                  for (var index = 0; index < slots.length; index += 1)
                    BestElevenEntry(
                      slotKey: slots[index],
                      slotIndex: index,
                      playerId: index + 1,
                      playerName: 'Player $index',
                      starts: 1,
                      jerseyNumber: index + 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      final cardOrigin = tester.getTopLeft(
        find.byKey(const ValueKey('team-best-eleven-card')),
      );
      Offset relativeCircleCenter(String slot) =>
          tester.getCenter(
            find.byKey(ValueKey('best-eleven-player-dot-$slot')),
          ) -
          cardOrigin;

      final center = tester
              .getSize(find.byKey(const ValueKey('team-best-eleven-card')))
              .width /
          2;
      for (final slot in ['1:1', '3:2', '4:2']) {
        expect(relativeCircleCenter(slot).dx, closeTo(center, 0.001));
      }
      for (final (left, right) in [
        ('2:1', '2:4'),
        ('2:2', '2:3'),
        ('3:1', '3:3'),
        ('4:1', '4:3'),
      ]) {
        expect(
          relativeCircleCenter(left).dx + relativeCircleCenter(right).dx,
          closeTo(2 * center, 0.001),
        );
        expect(
          relativeCircleCenter(left).dy,
          closeTo(relativeCircleCenter(right).dy, 0.001),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
