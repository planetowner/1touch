import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/data/team_trophies/mock/mock_team_trophy_repository.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/data/teams/mock/team_trophy_catalog.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/screens/AllPlayersScreen.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/Career.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('2025/26 catalog has unique stable IDs and balanced coverage', () {
    final players = playerRepository.allPlayers;
    final ids = players.map((player) => player.id).toSet();
    final leagues = players.map((player) => player.leagueName).toSet();
    final positions = players.expand((player) => player.positions).toSet();

    expect(players, hasLength(32));
    expect(ids, hasLength(players.length));
    expect(leagues, {
      'Premier League',
      'La Liga',
      'Bundesliga',
      'Ligue 1',
      'Serie A',
    });
    expect(positions, PlayerPosition.values.toSet());
    expect(
      players.every(
        (player) =>
            player.seasonStats.season == '2025/2026' &&
            player.radarValues.length == 5,
      ),
      isTrue,
    );
  });

  test('Korean and English aliases resolve the Korean players', () {
    expect(
      playerRepository.search('이강인').single.id,
      'lee-kang-in',
    );
    expect(
      playerRepository.search('Kangin Lee').single.id,
      'lee-kang-in',
    );
    expect(
      playerRepository.search('김민재').single.id,
      'kim-min-jae',
    );
    expect(
      playerRepository.search('Minjae Kim').single.id,
      'kim-min-jae',
    );
  });

  test('followed players update reactively and persist locally', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = MockPlayerRepository();

    await repository.updateFollowing(['lee-kang-in', 'harry-kane']);
    expect(
      repository.favorites.map((player) => player.id),
      ['lee-kang-in', 'harry-kane'],
    );

    await repository.toggleFollowing('lee-kang-in');
    expect(repository.isFollowing('lee-kang-in'), isFalse);

    final restored = MockPlayerRepository();
    await restored.initializeFollowing();
    expect(restored.followedPlayerIds.value, ['harry-kane']);
  });

  test('detailed career seasons connect players to teams and team trophies',
      () {
    final expectedSeasonCounts = {
      'lee-kang-in': 6,
      'kim-min-jae': 4,
      'harry-kane': 6,
      'mohamed-salah': 6,
    };

    for (final entry in expectedSeasonCounts.entries) {
      final player = playerRepository.findById(entry.key)!;
      expect(player.careerSeasons, hasLength(entry.value));
      expect(
        player.careerSeasons.every(
          (season) => mockTeams.any((team) => team.teamId == season.teamId),
        ),
        isTrue,
        reason: '${entry.key} has a career season without a matching team',
      );
    }

    final kim = playerRepository.findById('kim-min-jae')!;
    final napoliSeason = kim.careerSeasons.singleWhere(
      (season) => season.teamId == 597 && season.seasonLabel == '22/23',
    );
    expect(napoliSeason.competitions, hasLength(3));
    expect(
      MockTeamTrophyRepository().forTeamSeason(597, '22/23').single.name,
      'Serie A',
    );
    expect(
      kim.personalAwards.single.name,
      'Serie A Defender of the Year',
    );
    expect(
      mockTeamTrophies.map((trophy) => trophy.id).toSet(),
      hasLength(mockTeamTrophies.length),
    );
  });

  testWidgets('player profile renders the selected repository player',
      (tester) async {
    final player = playerRepository.findById('lee-kang-in')!;

    await tester.pumpWidget(
      MaterialApp(home: PlayerCard(player: player)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lee Kang-in'), findsOneWidget);
    expect(find.text('Paris Saint-Germain'), findsAtLeastNWidgets(1));
    expect(find.text('South Korea 🇰🇷'), findsOneWidget);
    expect(find.text('Heungmin Son'), findsNothing);
  });

  testWidgets('career tab joins team trophies and expands season competitions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = playerRepository.findById('lee-kang-in')!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CareerTab(player: player)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PARIS SAINT GERMAIN'), findsOneWidget);
    expect(find.text('Ligue 1'), findsOneWidget);
    expect(find.text('UEFA Champions League'), findsOneWidget);
    expect(
      find.byKey(const Key('career-competition-591-25/26-LIGUE 1')),
      findsOneWidget,
    );

    final newestSeason = find.byKey(
      const Key('career-season-591-25/26'),
    );
    await tester.ensureVisible(newestSeason);
    await tester.pumpAndSettle();
    await tester.tap(newestSeason);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('career-competition-591-25/26-LIGUE 1')),
      findsNothing,
    );
  });

  testWidgets('career competition and personal award filters are functional',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = playerRepository.findById('lee-kang-in')!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CareerTab(player: player)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('career-competition-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UCL').last);
    await tester.pumpAndSettle();

    expect(find.text('UCL'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('career-season-591-25/26')), findsOneWidget);
    expect(find.byKey(const Key('career-season-645-22/23')), findsNothing);

    await tester.tap(find.byKey(const Key('career-trophy-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PERSONAL').last);
    await tester.pumpAndSettle();

    expect(
      find.text('No personal awards in the mock dataset'),
      findsOneWidget,
    );
  });
}
