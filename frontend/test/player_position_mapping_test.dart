import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/player_position_mapping.dart';

void main() {
  test('maps backend position IDs to frontend abbreviations', () {
    expect(playerPositionAbbreviations, {
      24: 'GK',
      148: 'CB',
      149: 'DM',
      150: 'AM',
      151: 'ST',
      152: 'LW',
      153: 'CM',
      154: 'RB',
      155: 'LB',
      156: 'RW',
      157: 'LM',
      158: 'RM',
      163: 'SS',
    });
  });

  test('normalizes SportsMonks CF to the frontend ST convention', () {
    expect(normalizePlayerPositionAbbreviation('CF'), 'ST');
    expect(normalizePlayerPositionAbbreviation(' cf '), 'ST');
    expect(playerPositionAbbreviationFromId(151), 'ST');
  });

  test('normalizes casing without changing other abbreviations', () {
    expect(normalizePlayerPositionAbbreviation(' lw '), 'LW');
  });

  test('returns null for an unknown position ID', () {
    expect(playerPositionAbbreviationFromId(-1), isNull);
  });
}
