import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/community/community_rules_visit_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/features/community/community_ban_dialog.dart';
import 'package:onetouch/screens/CommunityScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_catalog.dart';
import 'support/stub_community_repository.dart';

void main() {
  setUpAppCatalog();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('ban countdown stays disabled until expiry at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.utc(2026, 10, 1);
      bool? acknowledged;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                acknowledged = await showCommunityBanDialog(
                  context,
                  ban: CommunityBanStatus(
                    username: 'Tester',
                    endsAt: now.add(const Duration(seconds: 2)),
                  ),
                  now: () => now,
                );
              },
              child: const Text('Open ban'),
            ),
          );
        }),
      ));
      await tester.tap(find.text('Open ban'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BackdropFilter), findsOneWidget);

      TextButton confirmation() => tester.widget<TextButton>(
            find.byKey(const ValueKey('community-ban-understand')),
          );
      String countdown() => tester
          .widget<Text>(find.byKey(const ValueKey('community-ban-time')))
          .textSpan!
          .toPlainText();
      expect(confirmation().onPressed, isNull);
      expect(countdown(), '00h 00m 02s');
      expect(find.text('due to [ban reason].'), findsOneWidget);
      expect(tester.takeException(), isNull);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(confirmation().onPressed, isNull);
      expect(countdown(), '00h 00m 01s');
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(confirmation().onPressed, isNotNull);
      expect(countdown(), '00h 00m 00s');
      await tester.tap(find.byKey(const ValueKey('community-ban-understand')));
      await tester.pumpAndSettle();
      expect(acknowledged, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('community opens ban first, then ten-second rules',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final visits = LocalCommunityRulesVisitRepository(
      loadUserId: () async => 42,
    );

    await tester.pumpWidget(MaterialApp(
      home: Community(
        teamId: 83,
        banStatus: CommunityBanStatus(
          username: 'Tester',
          endsAt: DateTime.now(),
        ),
        postRepository: MockPostRepository(posts: const []),
        communityRepository: const StubCommunityRepository(),
        fixtureRepository: MockFixtureRepository(fixtures: const []),
        rulesVisitRepository: visits,
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsNothing);

    await tester.tap(find.byKey(const ValueKey('community-ban-understand')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsOneWidget);
    final confirm = find.byKey(const ValueKey('community-rules-understand'));
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 5));
    final fill = find.byKey(const ValueKey('community-rules-reading-fill'));
    expect(
        tester.widget<FractionallySizedBox>(fill).widthFactor, greaterThan(0));
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<FractionallySizedBox>(fill).widthFactor,
        closeTo(1, 0.001));
    await tester.pump();
    expect(tester.widget<TextButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(await visits.shouldShow(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
