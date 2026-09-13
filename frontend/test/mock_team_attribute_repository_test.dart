import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/team_attributes/mock/mock_team_attribute_repository.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

void main() {
  const older = TeamAttributeScores(
    teamId: 8,
    competitionId: 8,
    seasonId: 100,
    seasonLabel: 'Older',
    attack: 10,
    progression: 20,
    dominance: 40,
    defense: 50,
    possession: 60,
  );
  const newer = TeamAttributeScores(
    teamId: 8,
    competitionId: 8,
    seasonId: 200,
    seasonLabel: 'Newer',
    attack: 60,
    progression: 50,
    dominance: 30,
    defense: 20,
    possession: 10,
  );
  const otherTeam = TeamAttributeScores(
    teamId: 19,
    competitionId: 8,
    seasonId: 300,
    seasonLabel: 'Other',
    attack: 50,
    progression: 50,
    dominance: 50,
    defense: 50,
    possession: 50,
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
