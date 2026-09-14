import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/models/team_contract_roster.dart';

void main() {
  test('identifies current and historical roster queries separately', () {
    const current = TeamContractQuery(teamId: 83);
    const sameCurrent = TeamContractQuery(teamId: 83);
    const historical = TeamContractQuery(teamId: 83, seasonId: 23621);
    const otherTeam = TeamContractQuery(teamId: 19);

    expect(current, sameCurrent);
    expect(current.hashCode, sameCurrent.hashCode);
    expect(current, isNot(historical));
    expect(current, isNot(otherTeam));
    expect({current: 'current', historical: 'historical'}, hasLength(2));
  });

  test('preserves the verified position-group IDs', () {
    expect(TeamPositionGroup.goalkeeper.apiId, 24);
    expect(TeamPositionGroup.defender.apiId, 25);
    expect(TeamPositionGroup.midfielder.apiId, 26);
    expect(TeamPositionGroup.forward.apiId, 27);
  });
}
