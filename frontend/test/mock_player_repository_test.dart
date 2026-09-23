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
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'support/player_detail_fixture.dart';

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

  testWidgets('player profile uses the provider identity and current team',
      (tester) async {
    final detail = detailFixture();
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(playerId: detail.playerId, initialDetail: detail)));
    await tester.pumpAndSettle();
    expect(find.text(detail.profile.name), findsOneWidget);
    expect(find.text(detail.profile.teamName!), findsAtLeastNWidgets(1));
    expect(find.text(detail.profile.nationality!), findsOneWidget);
    expect(find.text('Heungmin Son'), findsNothing);
  });

  testWidgets(
      'career joins actual team trophies and expands competition history',
      (tester) async {
    final json = playerDetailJson();
    json['honours'] = [
      {
        'team_id': 591,
        'team_name': 'Paris Saint-Germain',
        'team_image': null,
        'competition_id': 301,
        'competition_name': 'Ligue 1',
        'season_name': '2024/2025'
      },
    ];
    final detail = playerDetailFromJson(json);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlayerDetailScope(
                store: PlayerDetailStore(
                    playerId: detail.playerId, initial: detail),
                child: CareerTab(playerId: detail.playerId)))));
    await tester.pumpAndSettle();
    expect(find.text('PARIS SAINT-GERMAIN'), findsOneWidget);
    expect(find.text('PERSONAL'), findsNothing);
    final first = detail.career.first;
    final key = '${first.season}-${first.teamId}';
    final competition = find
        .byKey(Key('career-competition-$key-${first.competitions.first.id}'));
    expect(competition, findsOneWidget);
    final season = find.byKey(Key('career-season-$key'));
    await tester.ensureVisible(season);
    await tester.pumpAndSettle();
    await tester.tap(season);
    await tester.pumpAndSettle();
    expect(competition, findsNothing);
  });

  testWidgets(
      'career filter uses competition IDs and excludes unmatched seasons',
      (tester) async {
    final detail = detailFixture();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PlayerDetailScope(
                store: PlayerDetailStore(
                    playerId: detail.playerId, initial: detail),
                child: CareerTab(playerId: detail.playerId)))));
    await tester.pumpAndSettle();
    final id = detail.career.first.competitions.first.id;
    final filter = find.byKey(const Key('career-competition-filter'));
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(
        ListTile, detail.career.first.competitions.first.name.toUpperCase()));
    await tester.pumpAndSettle();
    final filteredSeason = find.byKey(Key(
        'career-season-${detail.career.first.season}-${detail.career.first.teamId}'));
    for (final season in detail.career) {
      expect(
          find.byKey(Key('career-season-${season.season}-${season.teamId}')),
          season.competitions.any((c) => c.id == id)
              ? findsOneWidget
              : findsNothing);
    }
    expect(
      find.descendant(
        of: filteredSeason,
        matching: find.byIcon(Icons.keyboard_arrow_down),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: filteredSeason,
        matching: find.byIcon(Icons.keyboard_arrow_up),
      ),
      findsNothing,
    );
    expect(find.text('PERSONAL'), findsNothing);
  });
}
