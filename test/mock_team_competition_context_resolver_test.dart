import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/teams/mock/mock_team_competition_context_resolver.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';

void main() {
  final resolver = MockTeamCompetitionContextResolver();

  test('resolves domestic competition context separately from Team', () {
    final context = resolver.resolve(19);

    expect(context?.teamId, 19);
    expect(context?.competitionId, 8);
    expect(context?.competitionName, 'Premier League');
    expect(context?.currentPosition, 2);
    expect(context?.label, 'Premier League 2nd');
  });

  test('returns null and an empty label for an unknown team', () {
    expect(resolver.resolve(-1), isNull);
    expect(resolver.labelFor(-1), isEmpty);
  });
}
