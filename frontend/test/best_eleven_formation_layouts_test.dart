import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/formation_layout.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_best_eleven.dart';

import 'support/app_catalog.dart';

// 구현의 계산식을 재사용하지 않고 Figma에서 읽은 원 중심과 대조해요.
final _designs = (jsonDecode(
  File('test/fixtures/figma_formation_positions.json').readAsStringSync(),
) as Map<String, dynamic>)['formations'] as List<dynamic>;

Map<String, Offset> _designPositions(String formation) {
  final design = _designs.singleWhere(
    (item) => item['formation'] == formationLayoutCode(formation),
  );
  final goalkeeper = design['goalkeeper'] as List<dynamic>;
  final rows = design['rows'] as List<dynamic>;
  return {
    '1:1': Offset(goalkeeper[0].toDouble(), goalkeeper[1].toDouble()),
    for (var row = 0; row < rows.length; row++)
      for (var column = 0; column < (rows[row] as List).length; column++)
        '${row + 2}:${column + 1}': Offset(
          rows[row][column][0].toDouble(),
          rows[row][column][1].toDouble(),
        ),
  };
}

List<BestElevenEntry> _players(String formation, {String language = 'en'}) {
  final counts = formation.split('-').map(int.parse).toList();
  final slots = [
    '1:1',
    for (var row = 0; row < counts.length; row++)
      for (var column = 1; column <= counts[row]; column++)
        '${row + 2}:$column',
  ];
  return [
    for (final (index, slot) in slots.indexed)
      BestElevenEntry(
        slotKey: slot,
        slotIndex: index,
        playerId: 990000 + index,
        playerName: language == 'ko' ? 'G. 마르틴' : 'G. Martín',
        starts: 1,
        jerseyNumber: index + 1,
      ),
  ];
}

Widget _pitch(String formation,
    {double nameWidth = 60, String language = 'en'}) {
  return MaterialApp(
    locale: Locale(language),
    localizationsDelegates: appLocalizationDelegates,
    supportedLocales: appSupportedLocales,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: BestElevenPitch(
          teamId: 503,
          formation: formation,
          players: _players(formation, language: language),
          playerNameWidth: nameWidth,
        ),
      ),
    ),
  );
}

Map<String, Offset> _checkCircleCenters(WidgetTester tester, String formation) {
  final card = tester.getRect(
    find.byKey(const ValueKey('team-best-eleven-card')),
  );
  final expected = _designPositions(formation);
  final actual = <String, Offset>{};
  for (final player in _players(formation)) {
    final dot = tester.getRect(
      find.byKey(ValueKey('best-eleven-player-dot-${player.slotKey}')),
    );
    final position =
        expected[formationLayoutSlotKey(formation, player.slotKey)]!;
    final center = dot.center - card.topLeft;
    expect(center.dx, closeTo(position.dx * card.width / 345, 0.001),
        reason: '$formation ${player.slotKey} x');
    expect(center.dy, closeTo(position.dy * card.height / 392, 0.001),
        reason: '$formation ${player.slotKey} y');
    expect(dot.width, closeTo(32, 0.001));
    expect(dot.height, closeTo(32, 0.001));
    final label = find.descendant(
      of: find.byKey(ValueKey('best-eleven-player-link-${player.playerId}')),
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.maxLines == 1,
      ),
    );
    expect(tester.getTopLeft(label).dy - dot.bottom, closeTo(4, 0.001));
    actual[player.slotKey] = center;
  }
  expect(actual.length, 11);
  expect(tester.takeException(), isNull);
  return actual;
}

void main() {
  setUpAppCatalog();

  for (final design in _designs) {
    final formation = design['formation'] as String;
    test('$formation uses the approved Formations coordinates', () {
      final layout = FormationLayout.forFormation(formation);
      final expected = _designPositions(formation);
      expect(expected.length, 11);
      for (final entry in expected.entries) {
        expect(layout.positionForSlot(entry.key), entry.value,
            reason: '$formation ${entry.key}');
      }
      for (final (row, positions) in layout.rows.indexed) {
        for (var column = 1; column <= positions.length; column++) {
          expect(
            layout.positionForSlot('${row + 2}:$column', reverseColumns: true),
            expected['${row + 2}:${positions.length - column + 1}'],
          );
        }
      }
    });
  }

  test('4-3-3 keeps the existing 4-1-2-3 shape and midfielder mapping', () {
    for (final formation in ['4-3-3', '433']) {
      expect(formationLayoutCode(formation), '4-1-2-3');
      expect(formationLayoutSlotKey(formation, '3:1'), '4:1');
      expect(formationLayoutSlotKey(formation, '3:2'), '3:1');
      expect(formationLayoutSlotKey(formation, '3:3'), '4:2');
      expect(formationLayoutSlotKey(formation, '4:1'), '5:1');
      expect(formationLayoutSlotKey(formation, '4:2'), '5:2');
      expect(formationLayoutSlotKey(formation, '4:3'), '5:3');
    }
    expect(formationLayoutCode('4-1-2-3'), '4-1-2-3');
    expect(formationLayoutCode('4123'), '4-1-2-3');
  });

  test('keeps slots for other or missing formations unchanged', () {
    for (final formation in [null, '4-1-2-3', '4-2-3-1']) {
      for (final slot in ['1:1', '2:4', '3:1', '3:2', '4:1', '5:3']) {
        expect(formationLayoutSlotKey(formation, slot), slot);
      }
    }
  });

  test('invalid formations use the designed 4-1-2-3 layout', () {
    final layout = FormationLayout.forFormation('invalid');
    for (final entry in _designPositions('4-1-2-3').entries) {
      expect(layout.positionForSlot(entry.key), entry.value);
    }
  });

  test('formations without a design keep the existing generated layout', () {
    final layout = FormationLayout.forFormation('2-2-2-2-2');
    expect(layout.rows.map((row) => row.length), [2, 2, 2, 2, 2]);
    expect(layout.positionForSlot('2:1'), const Offset(128.75, 264));
    expect(layout.positionForSlot('6:2'), const Offset(216.25, 40));
  });

  testWidgets('renders all 30 formations at their approved circle centers',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final design in _designs) {
      final formation = design['formation'] as String;
      await tester.pumpWidget(_pitch(formation));
      _checkCircleCenters(tester, formation);
    }
  });

  testWidgets('all formations fit the 345 by 784 Past lineup card',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final design in _designs) {
      final formation = design['formation'] as String;
      final layout = FormationLayout.forFormation(formation);
      final entries = _players(formation);
      List<List<LineupPlayer>> team(int id) => [
            [
              for (final entry in entries)
                LineupPlayer(
                  teamId: id,
                  playerId: entry.playerId,
                  number: entry.jerseyNumber,
                  name: entry.playerName!,
                  formationPosition: layout.positionForSlot(
                    formationLayoutSlotKey(formation, entry.slotKey),
                  ),
                ),
            ],
          ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LineupPitch(
              homeRows: team(1),
              awayRows: team(2),
              homeColor: Colors.red,
              awayColor: Colors.blue,
            ),
          ),
        ),
      ));
      final card = tester.getRect(
        find.byKey(const ValueKey('match-lineup-card')),
      );
      expect(card.size, const Size(345, 784));
      final heading = tester.getRect(find.text('LINEUP'));
      expect(card.top - heading.bottom, closeTo(16, 0.001));
      final expected = _designPositions(formation);
      for (final id in [1, 2]) {
        for (final entry in entries) {
          final player = find.byKey(
            ValueKey('match-lineup-player-$id-${entry.playerId}'),
          );
          final circle = tester.getRect(find.descendant(
            of: player,
            matching: find.byKey(const ValueKey('lineup-player-circle')),
          ));
          final position =
              expected[formationLayoutSlotKey(formation, entry.slotKey)]!;
          expect(circle.center.dx - card.left, closeTo(position.dx, 0.001));
          expect(circle.center.dy - card.top,
              closeTo(id == 1 ? 392 + position.dy : 372 - position.dy, 0.001));
          final label = find.descendant(
            of: player,
            matching: find.byWidgetPredicate(
              (widget) => widget is Text && widget.maxLines == 1,
            ),
          );
          expect(
              tester.getTopLeft(label).dy - circle.bottom, closeTo(4, 0.001));
        }
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    testWidgets('name width and language never move circles at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousLocale = appLocaleController.value;
      addTearDown(() => appLocaleController.value = previousLocale);
      Map<String, Offset>? baseline;
      for (final language in ['ko', 'en']) {
        appLocaleController.value = Locale(language);
        for (final width in [45.0, 60.0, 90.0]) {
          await tester.pumpWidget(
            _pitch('4-3-3', nameWidth: width, language: language),
          );
          final centers = _checkCircleCenters(tester, '4-3-3');
          baseline ??= centers;
          for (final entry in centers.entries) {
            expect((entry.value - baseline[entry.key]!).distance,
                closeTo(0, 0.001));
          }
          final playerWidth = tester
              .getSize(
                find.byKey(const ValueKey('best-eleven-player-link-990000')),
              )
              .width;
          final scale = (size.width - 48) / 345;
          expect(playerWidth, closeTo(width * (scale < 1 ? scale : 1), 0.001));
        }
      }
    });
  }
}
