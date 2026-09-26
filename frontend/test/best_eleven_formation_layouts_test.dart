import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/team/best_eleven/best_eleven_formation_layouts.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/models/team_best_eleven.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  test('every Figma formation maps all eleven slots', () {
    for (final entry in bestElevenFormationLayouts.entries) {
      final counts = entry.key.split('-').map(int.parse).toList();
      expect(
        counts.fold<int>(0, (total, count) => total + count),
        10,
        reason: entry.key,
      );
      expect(entry.value.positionForSlot('1:1'), isNotNull, reason: entry.key);
      for (var row = 0; row < counts.length; row += 1) {
        for (var column = 1; column <= counts[row]; column += 1) {
          expect(
            entry.value.positionForSlot('${row + 2}:$column'),
            isNotNull,
            reason: '${entry.key} row ${row + 2}, column $column',
          );
        }
      }
    }
  });

  test('4-3-3 keeps the staggered Figma coordinates', () {
    final layout = bestElevenFormationLayouts['4-3-3']!;

    expect(layout.positionForSlot('1:1'), const Offset(173, 340));
    expect(layout.positionForSlot('2:1'), const Offset(48, 220));
    expect(layout.positionForSlot('2:2'), const Offset(132, 252));
    expect(layout.positionForSlot('3:2'), const Offset(173, 152));
    expect(layout.positionForSlot('4:1'), const Offset(48, 72));
    expect(layout.positionForSlot('4:2'), const Offset(173, 44));
  });

  test('unknown valid formations receive a complete fallback layout', () {
    final layout = buildFallbackBestElevenLayout('2-2-2-2-2');

    expect(layout.positionForSlot('1:1'), isNotNull);
    for (var row = 2; row <= 6; row += 1) {
      expect(layout.positionForSlot('$row:1'), isNotNull);
      expect(layout.positionForSlot('$row:2'), isNotNull);
    }
  });

  testWidgets('393px pitch renders player circles at the Figma coordinates',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
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

    expect(relativeCircleCenter('1:1'), const Offset(173, 340));
    expect(relativeCircleCenter('2:1'), const Offset(48, 220));
    expect(relativeCircleCenter('2:2'), const Offset(132, 252));
    expect(relativeCircleCenter('3:2'), const Offset(173, 152));
    expect(relativeCircleCenter('4:2'), const Offset(173, 44));
    expect(tester.takeException(), isNull);
  });
}
