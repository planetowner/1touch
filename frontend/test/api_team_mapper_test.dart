import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';

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

    test('preserves nullable fields and the domain color default', () {
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
      expect(team.primaryColor, 0xFFD82457);
    });
  });
}
