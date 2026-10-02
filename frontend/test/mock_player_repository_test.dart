import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/data/team_trophies/mock/mock_team_trophy_repository.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/data/teams/mock/team_trophy_catalog.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/screens/all_players_screen.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/career.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
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
      {
        'team_id': 99901,
        'team_name': 'Korea Republic U23',
        'team_image': null,
        'competition_id': 99902,
        'competition_name': 'Coupe de France',
        'season_name': null
      },
      {
        'team_id': 99903,
        'team_name': null,
        'team_image': null,
        'competition_id': 99904,
        'competition_name': null,
        'season_name': '2023/2024'
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
    expect(find.text('KOREA REPUBLIC U23'), findsNothing);
    expect(find.text('Coupe de France'), findsNothing);
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

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('career trophy spacing fits $size', (tester) async {
      final json = playerDetailJson();
      json['honours'] = [
        {
          'team_id': 1001,
          'team_name': 'FC Barcelona',
          'competition_id': 2001,
          'competition_name': 'Spanish Champion',
          'season_name': '2022/2023',
        },
        {
          'team_id': 1001,
          'team_name': 'FC Barcelona',
          'competition_id': 2002,
          'competition_name': 'Spanish Super Cup',
          'season_name': '2022/2023',
        },
        {
          'team_id': 1001,
          'team_name': 'FC Barcelona',
          'competition_id': 2002,
          'competition_name': 'Spanish Super Cup',
          'season_name': '2024/2025',
        },
        {
          'team_id': 1002,
          'team_name': 'Sporting CP',
          'competition_id': 2003,
          'competition_name': 'Portuguese Cup',
          'season_name': '2019/2020',
        },
      ];
      final detail = playerDetailFromJson(json);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerDetailScope(
            store: PlayerDetailStore(
              playerId: detail.playerId,
              initial: detail,
            ),
            child: CareerTab(playerId: detail.playerId),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('player-career-trophies-card'));
      final logos = find.descendant(
        of: card,
        matching: find.byType(PlayerRemoteImage),
      );
      Finder seasonPill(String season) => find
          .ancestor(
            of: find.descendant(of: card, matching: find.text(season)).first,
            matching: find.byType(Container),
          )
          .first;
      final firstLogo = logos.first;
      final secondLogo = logos.last;
      final divider = find.descendant(
        of: card,
        matching: find.byType(Divider),
      );

      expect(find.descendant(of: card, matching: find.text('3')), findsNothing);
      expect(find.descendant(of: card, matching: find.text('1')), findsNothing);
      expect(tester.getRect(firstLogo).left - tester.getRect(card).left, 16);
      expect(tester.getRect(firstLogo).top - tester.getRect(card).top, 16);
      expect(
        tester.getRect(find.text('FC BARCELONA')).left -
            tester.getRect(firstLogo).right,
        12,
      );
      expect(
        tester.getRect(find.text('Spanish Champion')).top -
            tester.getRect(firstLogo).bottom,
        24,
      );
      expect(
        tester.getRect(seasonPill('22/23')).top -
            tester.getRect(find.text('Spanish Champion')).bottom,
        12,
      );
      expect(tester.getRect(seasonPill('22/23')).height, 33);
      expect(
        tester.getRect(divider).top -
            tester.getRect(seasonPill('24/25')).bottom,
        22,
      );
      expect(
        tester.getRect(secondLogo).top - tester.getRect(divider).bottom,
        26,
      );
      expect(
        tester.getRect(card).bottom -
            tester.getRect(seasonPill('19/20')).bottom,
        32,
      );
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.text('26/27'), findsOneWidget);
    expect(find.text('2026/2027'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('player-career-team-header')))
          .textAlign,
      TextAlign.center,
    );
    final filter = find.byKey(const Key('career-competition-filter'));
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    final optionLabel =
        detail.career.first.competitions.first.name.toUpperCase();
    final optionTile = find.widgetWithText(ListTile, optionLabel);
    final optionText = tester.widget<Text>(
      find.descendant(of: optionTile, matching: find.text(optionLabel)),
    );
    expect(optionText.style, Body2_b.style);
    await tester.tap(optionTile);
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
