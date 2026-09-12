import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/mock/team_analysis_catalog.dart';

void main() {
  test('uses the verified domestic season IDs for every displayed label', () {
    for (final scores in mockTeamAttributes) {
      expect(
        scores.seasonId,
        _seasonIds[(scores.teamId, scores.seasonLabel)],
        reason: 'team=${scores.teamId} season=${scores.seasonLabel}',
      );
    }
  });

  test('keeps team-season rows unique and scores inside the display range', () {
    final identities = <(int, int)>{};

    for (final scores in mockTeamAttributes) {
      expect(identities.add((scores.teamId, scores.seasonId)), isTrue);
      for (final value in scores.radarValues) {
        expect(value, inInclusiveRange(5, 95));
      }
    }
  });

  test('retains pressure in the provisional six-axis product order', () {
    expect(
      teamAttributeLabels,
      const [
        'Attack',
        'Progression',
        'Pressure',
        'Dominance',
        'Defense',
        'Possession',
      ],
    );
    expect(
      mockTeamAttributes.every((scores) => scores.radarValues.length == 6),
      isTrue,
    );
  });
}

const _seasonIds = <(int, String), int>{
  (83, '24/25'): 23621,
  (83, '22/23'): 19799,
  (83, '21/22'): 18462,
  (83, '20/21'): 17480,
  (3468, '24/25'): 23621,
  (3468, '22/23'): 19799,
  (3468, '21/22'): 18462,
  (8, '24/25'): 23614,
  (8, '22/23'): 19734,
  (19, '24/25'): 23614,
  (19, '22/23'): 19734,
  (9, '24/25'): 23614,
  (9, '22/23'): 19734,
  (503, '24/25'): 23744,
  (591, '24/25'): 23643,
  (2930, '24/25'): 23746,
};
