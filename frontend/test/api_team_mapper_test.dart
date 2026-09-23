import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/data/teams/team_color_palette_2627.dart';

void main() {
  group('teamFromApiResponse', () {
    test('maps every API-backed team field', () {
      final team = teamFromApiResponse(
        const ApiTeamResponse(
          teamId: 8,
          name: 'Liverpool',
          shortCode: 'LIV',
          imagePath: 'https://cdn.example/liverpool.png',
        ),
      );

      expect(team.teamId, 8);
      expect(team.name, 'Liverpool');
      expect(team.shortCode, 'LIV');
      expect(team.imagePath, 'https://cdn.example/liverpool.png');
    });

    test('preserves nullable fields and uses the shared team palette', () {
      final team = teamFromApiResponse(
        const ApiTeamResponse(
          teamId: 8,
          name: 'Liverpool',
          shortCode: null,
          imagePath: null,
        ),
      );

      expect(team.shortCode, isNull);
      expect(team.imagePath, isNull);
      expect(team.primaryColor, teamColorPaletteForName('Liverpool')!.primary);
    });
  });
}
