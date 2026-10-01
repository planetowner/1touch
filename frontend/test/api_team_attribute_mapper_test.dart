import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_mapper.dart';
import 'package:onetouch/data/team_attributes/api/api_team_attribute_response.dart';

void main() {
  test('maps the five backend scores into radar order without rounding', () {
    final scores = teamAttributeScoresFromApiResponse(
      const ApiTeamAttributeResponse(
        competitionId: 564,
        seasonId: 27965,
        seasonName: '2026/2027',
        isCurrent: true,
        teamId: 83,
        teamName: 'FC Barcelona',
        modelId: 1,
        possessionBuildUp: 82.8,
        attackingThreat: 73.57,
        chanceCreation: 86.39,
        finishing: 79.76,
        defending: 72.96,
        attributesUpdatedAt: '2026-09-12T14:02:20Z',
      ),
    );

    expect(scores.teamId, 83);
    expect(scores.competitionId, 564);
    expect(scores.seasonId, 27965);
    expect(scores.seasonLabel, '2026/2027');
    expect(scores.shootingFinishing, 79.76);
    expect(scores.attackingThreat, 73.57);
    expect(scores.chanceCreation, 86.39);
    expect(scores.defending, 72.96);
    expect(scores.possessionBuildUp, 82.8);
    expect(scores.radarValues, [82.8, 73.57, 86.39, 79.76, 72.96]);
  });
}
