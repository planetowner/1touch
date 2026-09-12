import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/home/api/api_home_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';
import 'package:onetouch/features/HomeScreenFeatures.dart';

void main() {
  testWidgets('calendar displays opponent data carried by the Home API fixture',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final startingAt = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-15 14:00:00';
    final home = homeDataFromApiResponse(
      ApiHomeResponse(
        favoriteTeam: const ApiTeamResponse(
          teamId: 8,
          name: 'Liverpool',
          shortCode: 'LIV',
          imagePath: 'https://cdn.example/8.png',
        ),
        followingTeams: const [
          ApiTeamResponse(
            teamId: 8,
            name: 'Liverpool',
            shortCode: 'LIV',
            imagePath: 'https://cdn.example/8.png',
          ),
        ],
        nextMatch: null,
        lastMatch: null,
        calendar: [
          ApiFixtureResponse(
            fixtureId: 1003,
            competitionId: 2,
            seasonId: 25583,
            competitionType: 'europe',
            roundName: null,
            stageId: 77432101,
            stageName: 'League Stage',
            roundId: null,
            groupId: null,
            aggregateId: null,
            leg: '1/1',
            venueId: null,
            stateId: 1,
            stateCode: 'NS',
            stateName: 'Not Started',
            status: 'upcoming',
            startingAt: startingAt,
            homeTeamId: 8,
            awayTeamId: 999,
            homeScore: null,
            awayScore: null,
            homePenaltyScore: null,
            awayPenaltyScore: null,
            homeTeamName: 'Liverpool',
            awayTeamName: 'European Opponent',
            homeTeamLogo: 'https://cdn.example/8.png',
            awayTeamLogo: 'https://cdn.example/opponent.png',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FixtureCalendar(
              allMatches: home.calendar,
              favoriteTeamId: home.favoriteTeam.teamId,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
        (image.image as NetworkImage).url, 'https://cdn.example/opponent.png');
    expect(tester.takeException(), isNull);
  });
}
