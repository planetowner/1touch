import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/mock/mock_team_competition_context_resolver.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';

void main() {
  final resolver = MockTeamCompetitionContextResolver();

  test('resolves domestic competition context separately from Team', () {
    final context = resolver.resolve(19);

    expect(context?.teamId, 19);
    expect(context?.seasonId, 25583);
    expect(context?.competitionId, 8);
    expect(context?.competitionName, 'Premier League');
    expect(context?.currentPosition, 2);
    expect(context?.label, 'Premier League 2nd');
  });

  test('returns null and an empty label for an unknown team', () {
    expect(resolver.resolve(-1), isNull);
    expect(resolver.labelFor(-1), isEmpty);
  });

  test('resolves current membership even when standing data is missing', () {
    final resolverWithoutStandings = MockTeamCompetitionContextResolver(
      standings: const [],
    );

    final context = resolverWithoutStandings.resolve(19);
    expect(context?.seasonId, 25583);
    expect(context?.competitionId, 8);
    expect(context?.competitionName, 'Premier League');
    expect(context?.currentPosition, isNull);
    expect(context?.label, 'Premier League');
  });

  test('does not present a previous-season-only team as current', () {
    expect(resolver.resolve(116), isNull);
    expect(resolver.labelFor(116), isEmpty);
  });
}
