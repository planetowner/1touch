import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_attributes/mock/mock_team_attribute_repository.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

void main() {
  const older = TeamAttributeScores(
    teamId: 8,
    competitionId: 8,
    seasonId: 100,
    seasonLabel: 'Older',
    shootingFinishing: 10,
    attackingThreat: 20,
    chanceCreation: 40,
    defending: 50,
    possessionBuildUp: 60,
  );
  const newer = TeamAttributeScores(
    teamId: 8,
    competitionId: 8,
    seasonId: 200,
    seasonLabel: 'Newer',
    shootingFinishing: 60,
    attackingThreat: 50,
    chanceCreation: 30,
    defending: 20,
    possessionBuildUp: 10,
  );
  const otherTeam = TeamAttributeScores(
    teamId: 19,
    competitionId: 8,
    seasonId: 300,
    seasonLabel: 'Other',
    shootingFinishing: 50,
    attackingThreat: 50,
    chanceCreation: 50,
    defending: 50,
    possessionBuildUp: 50,
  );

  test('returns only the requested team ordered by newest season', () async {
    final repository = MockTeamAttributeRepository(
      scores: const [older, otherTeam, newer],
    );

    final result = await repository.loadForTeam(8);

    expect(result, const [newer, older]);
    expect(() => result.add(otherTeam), throwsUnsupportedError);
  });

  test('filters the requested team by season', () async {
    final repository = MockTeamAttributeRepository(
      scores: const [older, otherTeam, newer],
    );

    expect(await repository.loadForTeam(8, seasonId: 100), const [older]);
    expect(await repository.loadForTeam(8, seasonId: 999), isEmpty);
  });

  test('returns an immutable empty list for an unknown team', () async {
    final repository = MockTeamAttributeRepository(scores: const [newer]);

    final result = await repository.loadForTeam(999999);

    expect(result, isEmpty);
    expect(() => result.add(otherTeam), throwsUnsupportedError);
  });
}
