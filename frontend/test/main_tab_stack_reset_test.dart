import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Profile_settings/about.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/features/community/community_ui.dart';
import 'package:onetouch/data/community/community_rules_visit_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/main.dart';
import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/screens/CommunityScreen_utils/add_post.dart';
import 'package:onetouch/screens/CommunityScreen_utils/post_screen.dart';
import 'package:onetouch/screens/TeamProbabilityScreen.dart';
import 'package:onetouch/screens/TeamScreen_tabs/analysis.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'package:onetouch/screens/team_probability_what_if_screen.dart';

import 'support/app_catalog.dart';
import 'support/stub_community_repository.dart';

const _post = Post(
  postId: 1,
  teamId: 83,
  language: 'en',
  userId: 1001,
  category: PostCategory.general,
  title: 'Navigation test post',
  body: 'Post detail',
  createdAt: '2026-10-01T10:00:00Z',
);
const _paths = ['/home', '/team', '/players', '/community'];

enum _Detail {
  post(3, PostDetailScreen),
  composer(3, AddPost),
  probability(1, TeamProbabilityScreen),
  whatIf(1, TeamProbabilityWhatIfScreen);

  const _Detail(this.tabIndex, this.widgetType);
  final int tabIndex;
  final Type widgetType;
}

enum _ReturnFrom { sameTab, home, profile }

enum _BackMethod { button, system, swipe }

void main() {
  setUpAppCatalog();
  for (final detail in _Detail.values) {
    for (final returnFrom in _ReturnFrom.values) {
      testWidgets('${detail.name} returns to root from ${returnFrom.name}',
          (tester) async {
        final navigation = await _mountNavigation(tester, detail.tabIndex);
        final router = navigation.router;
        final branches = navigation.branches;

        final rootType = detail.tabIndex == 3 ? Community : ProbabilitySection;
        final rootState = tester.state(find.byType(rootType));
        await _openDetail(tester, detail);
        expect(find.byType(detail.widgetType), findsOneWidget);
        final navigator = branches[detail.tabIndex].navigatorKey.currentState!;
        expect(navigator.canPop(), isTrue);
        // 직접 쌓은 화면은 라우터 주소가 첫 화면과 같아도 닫혀야 해요.
        expect(router.routeInformationProvider.value.uri.path,
            _paths[detail.tabIndex]);

        if (returnFrom == _ReturnFrom.home) {
          await _tapTab(tester, 0);
          expect(find.text('home-root'), findsOneWidget);
          expect(navigator.canPop(), isTrue);
        } else if (returnFrom == _ReturnFrom.profile) {
          router.push('/profile/about');
          await _pumpNavigation(tester);
          expect(find.byType(AboutPage), findsOneWidget);
        }

        await _tapTab(tester, detail.tabIndex);
        expect(router.routeInformationProvider.value.uri.path,
            _paths[detail.tabIndex]);
        expect(navigator.canPop(), isFalse);
        expect(tester.state(find.byType(rootType)), same(rootState));
        for (final screen in _Detail.values) {
          expect(find.byType(screen.widgetType), findsNothing);
        }
        await _tapTab(tester, detail.tabIndex);
        expect(navigator.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final detail in _Detail.values) {
    for (final method in _BackMethod.values) {
      testWidgets('${detail.name} ${method.name} back removes only one screen',
          (tester) async {
        final navigation = await _mountNavigation(tester, detail.tabIndex);
        final rootType = detail.tabIndex == 3 ? Community : ProbabilitySection;
        final rootState = tester.state(find.byType(rootType));
        await _openDetail(tester, detail);
        final serial = mainTabActions.serial;
        final probabilityState = detail == _Detail.whatIf
            ? tester
                .state(find.byType(TeamProbabilityScreen, skipOffstage: false))
            : null;
        final navigator =
            navigation.branches[detail.tabIndex].navigatorKey.currentState!;

        await _goBack(tester, detail, method);
        expect(find.byType(detail.widgetType), findsNothing);
        expect(mainTabActions.serial, serial);
        if (detail == _Detail.whatIf) {
          expect(find.byType(TeamProbabilityScreen), findsOneWidget);
          expect(tester.state(find.byType(TeamProbabilityScreen)),
              same(probabilityState));
          expect(navigator.canPop(), isTrue);
          await _goBack(tester, _Detail.probability, method);
        }
        expect(navigator.canPop(), isFalse);
        expect(tester.state(find.byType(rootType)), same(rootState));
        expect(mainTabActions.serial, serial);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('cancelled back swipe keeps composer input and its screen',
      (tester) async {
    await _mountNavigation(tester, 3);
    await _openDetail(tester, _Detail.composer);
    final composerState = tester.state(find.byType(AddPost));
    final title = find.byKey(const ValueKey('community-post-title-input'));
    await tester.enterText(title, 'Keep this draft');
    tester.testTextInput.hide();
    await _pumpNavigation(tester);
    final serial = mainTabActions.serial;
    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    await gesture.cancel();
    await _pumpNavigation(tester);
    expect(tester.state(find.byType(AddPost)), same(composerState));
    expect(tester.widget<TextField>(title).controller!.text, 'Keep this draft');
    expect(mainTabActions.serial, serial);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resetting Team preserves the inactive Community composer',
      (tester) async {
    final navigation = await _mountNavigation(tester, 3);
    final communityState = tester.state(find.byType(Community));
    await _openDetail(tester, _Detail.composer);
    final composerState = tester.state(find.byType(AddPost));
    final title = find.byKey(const ValueKey('community-post-title-input'));
    await tester.enterText(title, 'Keep this draft');
    tester.testTextInput.hide();
    await _pumpNavigation(tester);
    final communityNavigator =
        navigation.branches[3].navigatorKey.currentState!;

    await _tapTab(tester, 1);
    final teamState = tester.state(find.byType(ProbabilitySection));
    await _openDetail(tester, _Detail.whatIf);
    final whatIfState = tester.state(find.byType(TeamProbabilityWhatIfScreen));
    await _tapTab(tester, 0);
    final teamNavigator = navigation.branches[1].navigatorKey.currentState!;
    expect(communityNavigator.canPop(), isTrue);
    expect(teamNavigator.canPop(), isTrue);
    expect(
        tester.state(
            find.byType(TeamProbabilityWhatIfScreen, skipOffstage: false)),
        same(whatIfState));

    await _tapTab(tester, 1);
    expect(teamNavigator.canPop(), isFalse);
    expect(tester.state(find.byType(ProbabilitySection)), same(teamState));
    expect(communityNavigator.canPop(), isTrue);
    expect(tester.state(find.byType(AddPost, skipOffstage: false)),
        same(composerState));
    expect(tester.state(find.byType(Community, skipOffstage: false)),
        same(communityState));
    expect(
        tester
            .widget<TextField>(find.byKey(
                const ValueKey('community-post-title-input'),
                skipOffstage: false))
            .controller!
            .text,
        'Keep this draft');

    // 하단 탭을 누르지 않고 복원해, 숨겨진 화면의 상태가 실제로 남았는지 확인해요.
    tester
        .widget<MainScreen>(find.byType(MainScreen))
        .navigationShell
        .goBranch(3);
    await _pumpNavigation(tester);
    expect(tester.state(find.byType(AddPost)), same(composerState));
    await _goBack(tester, _Detail.composer, _BackMethod.button);
    expect(tester.state(find.byType(Community)), same(communityState));
    expect(communityNavigator.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<({GoRouter router, List<StatefulShellBranch> branches})>
    _mountNavigation(WidgetTester tester, int initialTabIndex) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final probabilityRepository = _ProbabilityRepository();
  final roots = <Widget>[
    const Text('home-root'),
    Scaffold(
      body: SingleChildScrollView(
        child: ProbabilitySection(
          teamId: 83,
          repository: probabilityRepository,
        ),
      ),
    ),
    const Text('players-root'),
    Community(
      teamId: 83,
      postRepository: MockPostRepository(posts: const [_post]),
      communityRepository: const StubCommunityRepository(),
      fixtureRepository: MockFixtureRepository(fixtures: const []),
      rulesVisitRepository: LocalCommunityRulesVisitRepository(
        loadUserId: () async => null,
      ),
    ),
  ];
  final branches = [
    for (var index = 0; index < roots.length; index++)
      StatefulShellBranch(routes: [
        GoRoute(
          path: _paths[index],
          builder: (_, __) => roots[index],
        ),
      ]),
  ];
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: _paths[initialTabIndex],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainScreen(navigationShell: shell),
        branches: branches,
      ),
      profileAboutRoute(navigatorKey: rootNavigatorKey),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpNavigation(tester);
    router.dispose();
    probabilityRepository.cachedSnapshots.dispose();
  });
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
    theme: app_style.whitetheme.copyWith(platform: TargetPlatform.iOS),
  ));
  await _pumpNavigation(tester);
  return (router: router, branches: branches);
}

Future<void> _openDetail(WidgetTester tester, _Detail detail) async {
  switch (detail) {
    case _Detail.post:
      await tester.ensureVisible(find.text(_post.title));
      await tester.tap(find.text(_post.title));
    case _Detail.composer:
      await tester.tap(find.byType(FloatingActionButton));
    case _Detail.probability:
    case _Detail.whatIf:
      await tester.tap(
          find.byKey(const ValueKey('team-probability-card-league_winner')));
      if (detail == _Detail.whatIf) {
        await _pumpNavigation(tester);
        await tester
            .tap(find.byKey(const ValueKey('probability-what-if-button')));
      }
  }
  await _pumpNavigation(tester);
}

Future<void> _goBack(
    WidgetTester tester, _Detail detail, _BackMethod method) async {
  switch (method) {
    case _BackMethod.button:
      final back = switch (detail) {
        _Detail.probability =>
          find.byKey(const ValueKey('probability-back-button')),
        _Detail.whatIf => find.byKey(const ValueKey('what-if-back-button')),
        _ => find.ancestor(
            of: find.byWidgetPredicate(
                (widget) => widget is CommunityIcon && widget.name == 'back'),
            matching: find.byType(IconButton)),
      };
      await tester.tap(back);
    case _BackMethod.system:
      await tester.binding.handlePopRoute();
    case _BackMethod.swipe:
      await tester.dragFrom(const Offset(2, 300), const Offset(420, 0));
  }
  await _pumpNavigation(tester);
}

Future<void> _tapTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('main-bottom-navigation-$index')));
  await _pumpNavigation(tester);
}

Future<void> _pumpNavigation(WidgetTester tester) async {
  // 비활성 커뮤니티 분류의 로딩 애니메이션은 끝나지 않으므로 화면 전환만 기다려요.
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _ProbabilityRepository implements TeamProbabilityRepository {
  final snapshot = _probabilitySnapshot();
  @override
  final ValueNotifier<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      cachedSnapshots = ValueNotifier({});

  @override
  TeamProbabilitySnapshot? cachedForTeam(int teamId, {int? seasonId}) =>
      snapshot;

  @override
  Future<TeamProbabilitySnapshot> loadForTeam(int teamId,
          {bool forceRefresh = false, int? seasonId}) async =>
      snapshot;
}

TeamProbabilitySnapshot _probabilitySnapshot() {
  const cards = [
    TeamProbabilityCard(
      event: 'league_winner',
      competitionId: 564,
      category: 'TITLE',
      probability: .3,
      changePercentagePoints: null,
      entropy: null,
    ),
  ];
  const points = TeamProjectedPoints(
    mean: 80,
    likelyRange: TeamPointsInterval(lower: 70, upper: 90),
    changePoints: null,
  );
  return TeamProbabilitySnapshot(
    teamId: 83,
    teamName: 'FC Barcelona',
    competitionId: 564,
    seasonId: 27965,
    seasonName: '2026/2027',
    asOf: DateTime.utc(2026, 10, 1),
    maximumPoints: 114,
    positions: const [],
    projectedPoints: points,
    comparison: const TeamProbabilityComparison(available: false, asOf: null),
    cards: cards,
    history: const [],
    pendingOutcomes: const [],
    whatIf: TeamProbabilityWhatIf(
      fixture: TeamProbabilityWhatIfFixture(
        fixtureId: 100,
        homeTeamId: 83,
        awayTeamId: 90,
        startingAt: DateTime.utc(2026, 10, 12),
        roundName: '9',
        probabilities: const [.5, .3, .2],
      ),
      scenarios: [
        for (final outcome in ['win', 'draw', 'loss'])
          TeamProbabilityWhatIfScenario(
            outcome: outcome,
            events: cards,
            positions: const [],
            projectedPoints: points,
          ),
      ],
    ),
  );
}
