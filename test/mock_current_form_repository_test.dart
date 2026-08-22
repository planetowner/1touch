import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/current_form/mock/mock_current_form_repository.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/team_season_membership.dart';

import 'support/current_form_repository_contract.dart';

void main() {
  group('MockCurrentFormRepository contract', () {
    currentFormRepositoryContract(
      createRepository: () => MockCurrentFormRepository(
        teams: _teams,
        seasons: _seasons,
        memberships: _memberships,
      ),
    );
  });

  test('uses the existing team and season catalogs by default', () async {
    final repository = MockCurrentFormRepository();
    final options = await repository.loadOptions(83, search: 'Barcelona');
    final comparison = await repository.loadComparison(
      83,
      compareTeamId: 83,
      compareSeasonId: 23621,
    );

    expect(options, isNotEmpty);
    expect(options.first.teamId, 83);
    expect(options.first.seasonName, anyOf('2025/2026', '2024/2025'));
    expect(comparison?.current.seasonId, 25659);
    expect(comparison?.comparison.seasonId, 23621);
  });
}

const _teams = [
  Team(teamId: 1, name: 'Alpha FC', shortCode: 'ALP'),
  Team(teamId: 2, name: 'Beta FC', shortCode: 'BET'),
];

const _seasons = [
  Season(
    seasonId: 100,
    competitionId: 8,
    name: '2025/26',
    isCurrent: true,
    startingAt: '2025-08-01',
    endingAt: '2026-05-31',
  ),
  Season(
    seasonId: 90,
    competitionId: 8,
    name: '2024/25',
    isCurrent: false,
    startingAt: '2024-08-01',
    endingAt: '2025-05-31',
  ),
];

const _memberships = [
  TeamSeasonMembership(teamId: 1, seasonId: 100, competitionId: 8),
  TeamSeasonMembership(teamId: 2, seasonId: 100, competitionId: 8),
  TeamSeasonMembership(teamId: 1, seasonId: 90, competitionId: 8),
];
