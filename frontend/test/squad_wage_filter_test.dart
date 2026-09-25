import 'support/app_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/features/team/squad/squad_player_presentation.dart';
import 'package:onetouch/models/team_contract_roster.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Squad.dart';

void main() {
  setUpAppCatalog();
  test('exposes the nullable wage sort option', () {
    expect(SortOption.wage.label, 'Wage');

    final player = SquadPlayer(
      id: 1,
      name: 'Player',
      teamLabel: 'Team • 1',
      jerseyNumber: 1,
      position: Position.GK,
      age: 25,
      contractEndYear: 2028,
    );
    expect(player.estimatedWeeklyGrossEur, isNull);
  });

  testWidgets('shows WAGE in the existing Squad sort menu', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeTeamContractRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: SquadTab(
            team: const {'id': 83, 'name': 'FC Barcelona'},
            contractRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API Player'), findsOneWidget);
    final playerCard = tester.widget<Container>(
      find.byKey(const ValueKey('squad-player-card-1')),
    );
    expect(
      (playerCard.decoration as BoxDecoration).boxShadow,
      lightModeCardShadows,
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey('squad-player-link-1')),
          )
          .onTap,
      isNotNull,
    );
    expect(repository.requestedSeasonIds, [27965]);
    expect(find.text('26/27'), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('26/27'))
          .didExceedMaxLines,
      isFalse,
    );
    await tester.tap(find.text('POSITION'));
    await tester.pumpAndSettle();

    expect(find.text('WAGE'), findsOneWidget);
    expect(find.text('CONTRACT LENGTH'), findsOneWidget);
    final dropdown = find.byKey(const ValueKey('squad-sort-dropdown'));
    final trigger = find.byKey(const ValueKey('squad-sort-trigger'));
    final arrow = find.byKey(const ValueKey('squad-sort-arrow'));
    final ascendingOption = find.byKey(
      const ValueKey('squad-sort-option-ascending'),
    );
    final positionOption = find.byKey(
      const ValueKey('squad-sort-option-position'),
    );
    final ascendingCheck = find.byKey(
      const ValueKey('squad-sort-selected-icon-ASCENDING'),
    );
    final positionCheck = find.byKey(
      const ValueKey('squad-sort-selected-icon-POSITION'),
    );
    expect(tester.getSize(dropdown).width, 166.5);
    expect(
      tester.getRect(trigger).right - tester.getRect(arrow).right,
      8,
    );
    expect(
      tester.getRect(ascendingOption).right -
          tester.getRect(ascendingCheck).right,
      8,
    );
    expect(
      tester.getRect(positionOption).right -
          tester.getRect(positionCheck).right,
      8,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('places season before sort and hides contract length in history',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeTeamContractRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: SquadTab(
            team: const {'id': 83, 'name': 'FC Barcelona'},
            contractRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final season = find.byKey(const ValueKey('squad-season-dropdown'));
    final sort = find.byKey(const ValueKey('squad-sort-dropdown'));
    expect(tester.getRect(season).right, lessThan(tester.getRect(sort).left));

    await tester.tap(find.byKey(const ValueKey('squad-season-trigger')));
    await tester.pumpAndSettle();
    expect(find.text('24/25'), findsOneWidget);
    expect(find.text('25/26'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('squad-season-option-23621')),
    );
    await tester.pumpAndSettle();
    expect(find.text('24/25'), findsOneWidget);
    expect(repository.requestedSeasonIds, [27965, 23621]);

    await tester.tap(find.byKey(const ValueKey('squad-sort-arrow')));
    await tester.pumpAndSettle();
    expect(find.text('CONTRACT LENGTH'), findsNothing);
    expect(find.text('WAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an API error and retries the roster request',
      (tester) async {
    final repository = _FakeTeamContractRepository(failuresRemaining: 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: SquadTab(
            team: const {'id': 83, 'name': 'FC Barcelona'},
            contractRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('squad-error')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('squad-retry')));
    await tester.pumpAndSettle();

    expect(find.text('API Player'), findsOneWidget);
    expect(repository.requestedSeasonIds, [27965, 27965]);
  });

  testWidgets('shows the empty state for an empty API roster', (tester) async {
    final repository = _FakeTeamContractRepository(returnEmpty: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: SquadTab(
            team: const {'id': 83, 'name': 'FC Barcelona'},
            contractRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('squad-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('squad-error')), findsNothing);
  });

  testWidgets('does not request a current roster without a known season',
      (tester) async {
    final repository = _FakeTeamContractRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: SquadTab(
            team: const {'id': 999999, 'name': 'Historical FC'},
            contractRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedSeasonIds, isEmpty);
    expect(find.byKey(const ValueKey('squad-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('squad-error')), findsNothing);
  });

  testWidgets('shows the exact captain and vice-captain card treatments',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: darktheme,
        home: Scaffold(
          body: SquadTab(
            team: const {'id': 83, 'name': 'FC Barcelona'},
            contractRepository: _FakeTeamContractRepository(
              includeLeadershipPlayers: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final captain = find.byKey(
      const ValueKey('squad-leadership-captain-1'),
    );
    final viceCaptain = find.byKey(
      const ValueKey('squad-leadership-vice-captain-2'),
    );
    final captainBadge = tester.widget<Container>(captain);
    final captainDecoration = captainBadge.decoration! as BoxDecoration;

    expect(captain, findsOneWidget);
    expect(tester.getSize(captain), const Size(24, 18));
    expect(captainDecoration.border, Border.all(color: AppPalette.white));
    expect(
        find.descendant(of: captain, matching: find.text('C')), findsOneWidget);
    expect(viceCaptain, findsOneWidget);
    expect(tester.widget<Text>(viceCaptain).style?.color, AppPalette.white);
    expect(find.text('VC'), findsOneWidget);
  });
}

class _FakeTeamContractRepository implements TeamContractRepository {
  _FakeTeamContractRepository({
    this.failuresRemaining = 0,
    this.returnEmpty = false,
    this.includeLeadershipPlayers = false,
  });

  final ValueNotifier<Map<TeamContractQuery, TeamContractRoster>> _cache =
      ValueNotifier(const {});
  final List<int?> requestedSeasonIds = [];
  int failuresRemaining;
  final bool returnEmpty;
  final bool includeLeadershipPlayers;

  @override
  ValueListenable<Map<TeamContractQuery, TeamContractRoster>>
      get cachedRosters => _cache;

  @override
  TeamContractRoster? cachedForTeam(int teamId, {int? seasonId}) {
    return _cache.value[TeamContractQuery(teamId: teamId, seasonId: seasonId)];
  }

  @override
  Future<TeamContractRoster> loadForTeam(int teamId, {int? seasonId}) async {
    requestedSeasonIds.add(seasonId);
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('Test roster failure');
    }
    final roster = TeamContractRoster(
      teamId: teamId,
      seasonId: seasonId ?? 27965,
      isCurrent: seasonId == 27965,
      players: returnEmpty
          ? const []
          : [
              TeamPlayerContract(
                playerId: 1,
                playerName: 'API Player',
                positionGroup: TeamPositionGroup.forward,
                jerseyNumber: 9,
                dateOfBirth: DateTime.utc(2000, 1, 1),
                estimatedWeeklyGrossEur: 100000,
                leadershipRole: includeLeadershipPlayers
                    ? TeamLeadershipRole.captain
                    : null,
                endDate: seasonId == 23621 ? null : DateTime.utc(2028, 6, 30),
              ),
              if (includeLeadershipPlayers)
                TeamPlayerContract(
                  playerId: 2,
                  playerName: 'Vice Captain',
                  positionGroup: TeamPositionGroup.forward,
                  jerseyNumber: 10,
                  leadershipRole: TeamLeadershipRole.viceCaptain,
                ),
            ],
    );
    _cache.value = Map.unmodifiable({
      ..._cache.value,
      TeamContractQuery(teamId: teamId, seasonId: seasonId): roster,
    });
    return roster;
  }
}
