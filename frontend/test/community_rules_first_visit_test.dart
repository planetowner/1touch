import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/community/community_rules_visit_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/models/community_rules.dart';
import 'package:onetouch/screens/CommunityScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_catalog.dart';
import 'support/stub_community_repository.dart';

void main() {
  setUpAppCatalog();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('acknowledgment persists for one account, not another', () async {
    int? userId = 1;
    final visits = LocalCommunityRulesVisitRepository(
      loadUserId: () async => userId,
    );
    expect(await visits.shouldShow(), isTrue);
    await visits.acknowledge();
    expect(await visits.shouldShow(), isFalse);
    userId = 2;
    expect(await visits.shouldShow(), isTrue);
    userId = 1;
    expect(
        await LocalCommunityRulesVisitRepository(
          loadUserId: () async => userId,
        ).shouldShow(),
        isFalse);
    userId = null;
    expect(await visits.shouldShow(), isFalse);
  });

  testWidgets(
      'first visit opens rules and confirmation suppresses later visits',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? userId = 1;
    final visits = LocalCommunityRulesVisitRepository(
      loadUserId: () async => userId,
    );
    Widget community() => MaterialApp(
          home: Community(
            teamId: 83,
            postRepository: MockPostRepository(posts: const []),
            communityRepository: const StubCommunityRepository(),
            fixtureRepository: MockFixtureRepository(fixtures: const []),
            rulesVisitRepository: visits,
          ),
        );

    await tester.pumpWidget(community());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsOneWidget);
    await tester.tap(find.text('I UNDERSTAND!'));
    await tester.pumpAndSettle();
    expect(await visits.shouldShow(), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(community());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsNothing);

    userId = 2;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(community());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing without confirmation leaves rules due next visit',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => mainTabActions.select(0));
    final visits = LocalCommunityRulesVisitRepository(
      loadUserId: () async => 3,
    );
    Widget community() => MaterialApp(
          home: Community(
            teamId: 83,
            postRepository: MockPostRepository(posts: const []),
            communityRepository: const StubCommunityRepository(),
            fixtureRepository: MockFixtureRepository(fixtures: const []),
            rulesVisitRepository: visits,
          ),
        );

    await tester.pumpWidget(community());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await visits.shouldShow(), isTrue);

    mainTabActions.select(0);
    mainTabActions.select(3);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rules load failure does not acknowledge the first visit',
      (tester) async {
    final visits = LocalCommunityRulesVisitRepository(
      loadUserId: () async => 4,
    );
    await tester.pumpWidget(MaterialApp(
      home: Community(
        teamId: 83,
        postRepository: MockPostRepository(posts: const []),
        communityRepository: _FailingRulesRepository(),
        fixtureRepository: MockFixtureRepository(fixtures: const []),
        rulesVisitRepository: visits,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-rules-error')), findsOneWidget);
    expect(await visits.shouldShow(), isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _FailingRulesRepository implements CommunityRepository {
  @override
  Future<int> loadFollowerCount({required int teamId}) async => 0;

  @override
  Future<CommunityRules> loadRules({required int teamId}) =>
      Future.error(StateError('Offline'));
}
