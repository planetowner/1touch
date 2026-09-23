import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

void main() {
  setUpAppCatalog();
  test('API short name leaves the original name and code available', () {
    final team = teamFromApiResponse(ApiTeamResponse.fromJson({
      'team_id': 83,
      'name': 'FC Barcelona',
      'short_name': 'Barcelona',
      'short_code': 'BAR',
      'image_path': null,
    }));
    expect(team.displayName, 'Barcelona');
    expect(team.name, 'FC Barcelona');
    expect(team.shortCode, 'BAR');
  });

  test('unlisted teams use the original name even if a code exists', () {
    const team = Team(teamId: 90, name: 'FC Augsburg', shortCode: 'FCA');
    expect(team.displayName, 'FC Augsburg');
  });

  test('API null short name is authoritative over the mock catalog', () {
    final repository = MockTeamRepository(teams: const [
      Team(teamId: 83, name: 'FC Barcelona', shortName: 'Old alias'),
    ]);
    final team = fixtureHomeTeam(_fixture(shortName: null), repository);
    expect(team.shortName, isNull);
    expect(team.displayName, 'FC Barcelona');
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets('match card names at $size dark=$dark', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: dark ? app_style.darktheme : app_style.whitetheme,
          home: Scaffold(body: MatchCard(match: _fixture())),
        ));
        expect(find.text('Barcelona'), findsOneWidget);
        expect(find.text('FC Augsburg'), findsOneWidget);
        expect(find.text('FC Barcelona'), findsNothing);
        expect(find.text('FCA'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Fixture _fixture({String? shortName = 'Barcelona'}) => Fixture(
      fixtureId: 1,
      seasonId: 1,
      competitionId: 2,
      homeTeamId: 83,
      awayTeamId: 90,
      homeTeamName: 'FC Barcelona',
      awayTeamName: 'FC Augsburg',
      homeTeamShortName: shortName,
      competitionType: CompetitionType.europe,
      roundName: null,
      status: FixtureStatus.upcoming,
      startingAt: null,
    );
