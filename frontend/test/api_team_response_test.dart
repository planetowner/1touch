import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';

void main() {
  group('ApiTeamResponse', () {
    test('parses the verified TeamOut response', () {
      final response = ApiTeamResponse.fromJson({
        'team_id': 8,
        'name': 'Liverpool',
        'short_code': 'LIV',
        'image_path': 'https://cdn.example/liverpool.png',
      });

      expect(response.teamId, 8);
      expect(response.name, 'Liverpool');
      expect(response.shortCode, 'LIV');
      expect(response.imagePath, 'https://cdn.example/liverpool.png');
    });

    test('preserves nullable short code and image path', () {
      final response = ApiTeamResponse.fromJson({
        'team_id': 8,
        'name': 'Liverpool',
        'short_code': null,
        'image_path': null,
      });

      expect(response.shortCode, isNull);
      expect(response.imagePath, isNull);
    });

    test('rejects missing or malformed required fields', () {
      for (final json in [
        <String, dynamic>{
          'name': 'Liverpool',
          'short_code': 'LIV',
          'image_path': null,
        },
        <String, dynamic>{
          'team_id': 8,
          'name': null,
          'short_code': 'LIV',
          'image_path': null,
        },
      ]) {
        expect(
          () => ApiTeamResponse.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('rejects malformed nullable fields', () {
      final json = <String, dynamic>{
        'team_id': 8,
        'name': 'Liverpool',
        'short_code': 8,
        'image_path': null,
      };

      expect(
        () => ApiTeamResponse.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('short_code'),
          ),
        ),
      );
    });
  });
}
