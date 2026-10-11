import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/page_refresh.dart';
import 'package:onetouch/data/current_form/mock/mock_current_form_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/posts/post_repository.dart';
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/data/standings/mock/mock_xg_standing_repository.dart';
import 'package:onetouch/data/team_attributes/mock/mock_team_attribute_repository.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/community/community_header_slivers.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/screens/all_players_screen.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'package:onetouch/screens/team_screen.dart';

import 'support/app_catalog.dart';
import 'support/player_detail_fixture.dart';
import 'support/stub_community_repository.dart';
import 'support/test_team_overview_repository.dart';

void main() {
  setUpAppCatalog(favoriteTeamId: 9);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('pull refresh reaches Community on $platform', (tester) async {
      final posts = _CountingPosts();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        home: Community(
          teamId: 9,
          postRepository: posts,
          communityRepository: const StubCommunityRepository(),
        ),
      ));
      await tester.pumpAndSettle();
      final tabs =
          tester.widget<TabBarView>(find.byType(TabBarView)).controller!;
      tester
          .widget<CommunitySortFilters>(find.byType(CommunitySortFilters))
          .onChanged(PostSort.popular);
      await tester.pumpAndSettle();
      for (var index = 0;
          index < CommunityPostTabHeader.categories.length;
          index++) {
        tabs.index = index;
        await tester.pumpAndSettle();
        final before = posts.calls;
        await _dragRefresh(tester);
        await tester.pumpAndSettle();
        expect(posts.calls, before + 1, reason: 'category $index');
        expect(posts.lastCategory, CommunityPostTabHeader.categories[index]);
        expect(posts.lastSort, PostSort.popular);
        expect(tabs.index, index);
      }
    });

    testWidgets('pull refresh reaches Team on $platform', (tester) async {
      final overview = TestTeamOverviewRepository.withTeam9();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        home: TeamScreen(
          teamId: 9,
          teamOverviewRepository: overview,
          fixtureRepository: MockFixtureRepository(),
          teamAttributeRepository: MockTeamAttributeRepository(),
          currentFormRepository: MockCurrentFormRepository(),
          standingRepository: MockStandingRepository(),
          xgStandingRepository: MockXgStandingRepository(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final tabs =
          tester.widget<TabBarView>(find.byType(TabBarView)).controller!;
      for (var index = 0; index < 5; index++) {
        tabs.index = index;
        await _pump(tester);
        for (final state
            in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
          if (state.position.axis == Axis.vertical) {
            state.position.jumpTo(state.position.minScrollExtent);
          }
        }
        // 안쪽 jumpTo가 헤더를 접으므로 바깥 스크롤을 마지막에 맨 위로 돌려요.
        final outer = tester
            .state<NestedScrollViewState>(find.byType(NestedScrollView))
            .outerController;
        outer.jumpTo(outer.position.minScrollExtent);
        await _pump(tester);
        expect(outer.position.extentBefore, 0);
        final before = overview.requestedTeamIds.length;
        await _dragRefresh(tester);
        await _pump(tester);
        expect(overview.requestedTeamIds.length, before + 1,
            reason: 'tab $index');
        expect(tabs.index, index);
      }
      await tester.pumpWidget(const SizedBox());
    });

    for (var index = 0; index < 4; index++) {
      testWidgets('pull refresh reaches player detail tab $index on $platform',
          (tester) async {
        final repository = FakePlayerDetailRepository();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(platform: platform),
          home: PlayerCard(
              playerId: 1,
              detailRepository: repository,
              initialTabIndex: index),
        ));
        await tester.pumpAndSettle();
        if (index == 1 || index == 2) {
          tester
              .widget<PlayerSeasonSelector>(find.byType(PlayerSeasonSelector))
              .onChanged(25651);
          await tester.pumpAndSettle();
        }
        final before = repository.calls.length;
        await _dragRefresh(tester);
        await tester.pumpAndSettle();
        expect(repository.calls.length, greaterThan(before));
        expect(
            tester
                .widget<TabBarView>(find.byType(TabBarView))
                .controller!
                .index,
            index);
        if (index == 1 || index == 2) {
          expect(repository.calls.last.seasonId, 25651);
          expect(
              tester
                  .widget<PlayerSeasonSelector>(
                      find.byType(PlayerSeasonSelector))
                  .detail
                  .selectedSeason
                  ?.id,
              25651);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('refresh waits for the selected season and keeps data on failure',
      (tester) async {
    final repository = _DelayedPlayerRepository();
    await tester.pumpWidget(MaterialApp(
      home: PlayerCard(
          playerId: 1, detailRepository: repository, initialTabIndex: 1),
    ));
    await tester.pumpAndSettle();
    tester
        .widget<PlayerSeasonSelector>(find.byType(PlayerSeasonSelector))
        .onChanged(25651);
    await tester.pumpAndSettle();
    repository.delayed = true;
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 400));
    await _pump(tester);
    expect(repository.pending.keys, unorderedEquals([null, 25651]));
    repository.pending[null]!.complete(detailFixture(playerId: 1));
    await _pump(tester);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(find.byType(PlayerSeasonSelector), findsOneWidget);
    repository.pending[25651]!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(
        tester
            .widget<PlayerSeasonSelector>(find.byType(PlayerSeasonSelector))
            .detail
            .selectedSeason
            ?.id,
        25651);
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal notifications do not trigger refresh',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: PageRefreshIndicator(
      onRefresh: () async {
        calls++;
      },
      builder: (context, physics) => ListView(
          scrollDirection: Axis.horizontal,
          children: const [SizedBox(width: 1200)]),
    )));
    await tester.drag(find.byType(ListView), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('Team refresh waits for analysis after the header has loaded',
      (tester) async {
    final attributes = _DelayedAttributes();
    final overview = TestTeamOverviewRepository.withTeam9();
    await tester.pumpWidget(MaterialApp(
        home: TeamScreen(
      teamId: 9,
      initialTabIndex: 4,
      teamOverviewRepository: overview,
      fixtureRepository: MockFixtureRepository(fixtures: []),
      teamAttributeRepository: attributes,
      currentFormRepository: MockCurrentFormRepository(),
    )));
    await _pump(tester);
    attributes.pending = Completer<void>();
    final before = overview.requestedTeamIds.length;
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 400));
    await _pump(tester);
    expect(overview.requestedTeamIds.length, before + 1);
    expect(attributes.forcedLoads, 1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    attributes.pending!.complete();
    await _pump(tester);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty Team fixtures can still be pulled to refresh',
      (tester) async {
    final overview = TestTeamOverviewRepository.withTeam9();
    await tester.pumpWidget(MaterialApp(
        home: TeamScreen(
      teamId: 9,
      initialTabIndex: 1,
      teamOverviewRepository: overview,
      fixtureRepository: MockFixtureRepository(fixtures: []),
    )));
    await _pump(tester);
    expect(find.byKey(const ValueKey('matches-empty')), findsOneWidget);
    final before = overview.requestedTeamIds.length;
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 400));
    await _pump(tester);
    expect(overview.requestedTeamIds.length, before + 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an empty Community error can be pulled to retry',
      (tester) async {
    final posts = _CountingPosts()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Community(
      teamId: 9,
      postRepository: posts,
      communityRepository: const StubCommunityRepository(),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-posts-retry')), findsOneWidget);
    posts.fail = false;
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(posts.calls, 2);
    expect(find.byKey(const ValueKey('community-posts-retry')), findsNothing);
  });

  testWidgets('player detail error can be pulled to retry', (tester) async {
    final repository = FakePlayerDetailRepository()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(
      playerId: 1,
      detailRepository: repository,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not load player data'), findsOneWidget);
    repository.fail = false;
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Could not load player data'), findsNothing);
    expect(
        find.byKey(const ValueKey('player-overview-scroll')), findsOneWidget);
  });
}

Future<void> _dragRefresh(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(200, 400));
  // 한 번에 크게 이동하면 실제 당김의 저항과 시작 동작을 확인할 수 없어요.
  for (var i = 0; i < 24; i++) {
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

class _DelayedPlayerRepository extends FakePlayerDetailRepository {
  bool delayed = false;
  final pending = <int?, Completer<PlayerDetail>>{};

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) {
    if (!delayed) return super.load(playerId, seasonId: seasonId);
    final response = Completer<PlayerDetail>();
    pending[seasonId] = response;
    return response.future;
  }
}

class _DelayedAttributes extends MockTeamAttributeRepository {
  Completer<void>? pending;
  int forcedLoads = 0;

  @override
  Future<List<TeamAttributeScores>> loadForTeam(
    int teamId, {
    bool forceRefresh = false,
    int? seasonId,
  }) async {
    if (forceRefresh) {
      forcedLoads++;
      await pending?.future;
    }
    return super
        .loadForTeam(teamId, seasonId: seasonId, forceRefresh: forceRefresh);
  }
}

class _CountingPosts extends MockPostRepository {
  int calls = 0;
  bool fail = false;
  PostCategory? lastCategory;
  PostSort? lastSort;

  @override
  Future<List<Post>> loadPosts({
    required int teamId,
    required String language,
    PostCategory? category,
    PostSort sort = PostSort.newest,
    PostPeriod period = PostPeriod.allTime,
    String? timezone,
    int limit = 50,
    int offset = 0,
  }) async {
    calls++;
    lastCategory = category;
    lastSort = sort;
    if (fail) throw StateError('offline');
    return [];
  }
}
