import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_response.dart';

void main() {
  group('ApiTeamAttributeResponse', () {
    test('parses the verified current-season response', () {
      final response = ApiTeamAttributeResponse.fromJson(_attributeJson());

      expect(response.competitionId, 564);
      expect(response.seasonId, 27965);
      expect(response.seasonName, '2026/2027');
      expect(response.isCurrent, isTrue);
      expect(response.teamId, 83);
      expect(response.teamName, 'FC Barcelona');
      expect(response.modelId, 1);
      expect(response.possessionBuildUp, 82.8);
      expect(response.attackingThreat, 73.57);
      expect(response.chanceCreation, 86.39);
      expect(response.finishing, 79.76);
      expect(response.defending, 72.96);
      expect(response.attributesUpdatedAt, '2026-09-12T14:02:20Z');
    });

    test('accepts integer JSON numbers for attribute scores', () {
      final response = ApiTeamAttributeResponse.fromJson({
        ..._attributeJson(),
        'possession_build_up': 82,
        'attacking_threat': 73,
        'chance_creation': 86,
        'finishing': 79,
        'defending': 72,
      });

      expect(response.possessionBuildUp, 82.0);
      expect(response.attackingThreat, 73.0);
      expect(response.chanceCreation, 86.0);
      expect(response.finishing, 79.0);
      expect(response.defending, 72.0);
    });

    test('requires every field in the deployed response', () {
      for (final field in _attributeJson().keys) {
        final json = _attributeJson()..remove(field);

        expect(
          () => ApiTeamAttributeResponse.fromJson(json),
          throwsFormatException,
          reason: 'missing $field should be rejected',
        );
      }
    });

    test('rejects malformed identifiers, flags, scores, and timestamps', () {
      for (final json in [
        _attributeJson()..['team_id'] = '83',
        _attributeJson()..['is_current'] = 1,
        _attributeJson()..['finishing'] = '79.76',
        _attributeJson()..['attributes_updated_at'] = null,
      ]) {
        expect(
          () => ApiTeamAttributeResponse.fromJson(json),
          throwsFormatException,
        );
      }
    });

    test('ignores additional backend fields', () {
      final response = ApiTeamAttributeResponse.fromJson({
        ..._attributeJson(),
        'future_attribute': 50.0,
      });

      expect(response.teamId, 83);
      expect(response.finishing, 79.76);
    });
  });
}

Map<String, dynamic> _attributeJson() {
  return {
    'competition_id': 564,
    'season_id': 27965,
    'season_name': '2026/2027',
    'is_current': true,
    'team_id': 83,
    'team_name': 'FC Barcelona',
    'model_id': 1,
    'possession_build_up': 82.8,
    'attacking_threat': 73.57,
    'chance_creation': 86.39,
    'finishing': 79.76,
    'defending': 72.96,
    'attributes_updated_at': '2026-09-12T14:02:20Z',
  };
}
