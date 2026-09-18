import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/team_color_palette_2627.dart';

void main() {
  group('2026/27 team color palette', () {
    test('contains every supplied Big Five team', () {
      expect(teamColorPalette2627, hasLength(96));
    });

    test('resolves frontend team-name aliases', () {
      expect(
        teamColorPaletteForName('Manchester City')?.primary,
        0xFF5FAFF1,
      );
      expect(
        teamColorPaletteForName('FC Barcelona')?.secondary,
        0xFF1B6EBD,
      );
      expect(
        teamColorPaletteForName('FC Bayern München')?.tertiary,
        0xFF8F4DBE,
      );
    });

    test('normalizes casing and whitespace', () {
      expect(
        teamColorPaletteForName('  MANCHESTER   UNITED  ')?.primary,
        0xFFEF2C34,
      );
    });

    test('does not classify Norwich as a 2026/27 Big Five team', () {
      expect(teamColorPaletteForName('Norwich City'), isNull);
      expect(isTeamInBigFive2627('Norwich City'), isFalse);
    });
  });
}
