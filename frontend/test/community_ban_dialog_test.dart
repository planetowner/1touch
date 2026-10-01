import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/data/community/community_rules_visit_repository.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/features/community/community_ban_dialog.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/community_ban.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_catalog.dart';
import 'support/stub_community_repository.dart';

void main() {
  setUpAppCatalog();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('ban countdown reaches zero and allows closing at $size',
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
                    reason: CommunityBanReason.harassment,
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
      expect(find.byType(BackdropFilter), findsNothing);

      TextButton confirmation() => tester.widget<TextButton>(
            find.byKey(const ValueKey('community-ban-close')),
          );
      String countdown() => tester
          .widget<Text>(find.byKey(const ValueKey('community-ban-time')))
          .textSpan!
          .toPlainText();
      expect(confirmation().onPressed, isNotNull);
      expect(countdown(), '00h 00m 02s');
      expect(
          find.text('Your access to the community has been restricted for '
              'harassing or insulting other users.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(confirmation().onPressed, isNotNull);
      expect(countdown(), '00h 00m 01s');
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(confirmation().onPressed, isNotNull);
      expect(countdown(), '00h 00m 00s');
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(countdown(), '00h 00m 00s');
      await tester.tap(find.byKey(const ValueKey('community-ban-close')));
      await tester.pumpAndSettle();
      expect(acknowledged, isTrue);
      expect(tester.takeException(), isNull);
    });

    for (final language in ['en', 'ko', 'ja', 'zh']) {
      testWidgets('all $language reasons fit the ban dialog at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.utc(2026, 10, 1);
        final copy = _copy[language]!;

        for (final entry in _reasons.entries) {
          bool? expired;
          await tester.pumpWidget(MaterialApp(
            locale: Locale(language),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationDelegates,
            home: Builder(builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    expired = await showCommunityBanDialog(
                      context,
                      ban: CommunityBanStatus(
                        reason: entry.key,
                        endsAt: now.add(
                            const Duration(hours: 1, minutes: 23, seconds: 45)),
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
          await tester.pumpAndSettle();
          expect(find.text(copy.title), findsOneWidget);
          expect(find.text(copy.body(entry.value[language]!)), findsOneWidget);
          expect(find.text(copy.notice), findsOneWidget);
          final countdown = tester
              .widget<Text>(find.byKey(const ValueKey('community-ban-time')));
          expect(countdown.textSpan!.toPlainText(), '01h 23m 45s');
          final close = find.byKey(const ValueKey('community-ban-close'));
          expect(find.text(copy.close), findsOneWidget);
          expect(tester.widget<TextButton>(close).onPressed, isNotNull);
          await tester.ensureVisible(close);
          await tester.pumpAndSettle();
          expect(tester.getRect(close).bottom, lessThanOrEqualTo(size.height));
          expect(tester.getRect(close).width, lessThan(size.width));
          expect(tester.takeException(), isNull);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(expired, isFalse);
          expect(
              find.byKey(const ValueKey('community-ban-dialog')), findsNothing);
        }
      });
    }
  }

  testWidgets('long copy stays scrollable with large text on a compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 10, 1);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () => showCommunityBanDialog(
              context,
              ban: CommunityBanStatus(
                reason: CommunityBanReason.impersonation,
                endsAt: now.add(const Duration(hours: 100)),
              ),
              now: () => now,
            ),
            child: const Text('Open ban'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Open ban'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final close = find.byKey(const ValueKey('community-ban-close'));
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing an active ban does not start return-to-community rules',
      (tester) async {
    final visits =
        LocalCommunityRulesVisitRepository(loadUserId: () async => 42);
    await tester.pumpWidget(MaterialApp(
      home: Community(
        teamId: 83,
        communityRepository: StubCommunityRepository(
          banStatus: CommunityBanStatus(
            reason: CommunityBanReason.spam,
            endsAt: DateTime.now().add(const Duration(hours: 1)),
          ),
        ),
        postRepository: MockPostRepository(posts: const []),
        fixtureRepository: MockFixtureRepository(fixtures: const []),
        rulesVisitRepository: visits,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.byKey(const ValueKey('community-ban-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsNothing);
    expect(await visits.shouldShow(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired server ban opens ten-second rules once per account',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final visits = LocalCommunityRulesVisitRepository(
      loadUserId: () async => 42,
    );

    final endedAt = DateTime.now().subtract(const Duration(seconds: 1));
    Widget community() => MaterialApp(
          home: Community(
            teamId: 83,
            communityRepository: StubCommunityRepository(
              banStatus: CommunityBanStatus(
                reason: CommunityBanReason.guidelinesViolation,
                endsAt: endedAt,
              ),
            ),
            postRepository: MockPostRepository(posts: const []),
            fixtureRepository: MockFixtureRepository(fixtures: const []),
            rulesVisitRepository: visits,
          ),
        );
    await tester.pumpWidget(community());
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsNothing);
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
    expect(await visits.shouldShow(suspensionEndsAt: endedAt), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(community());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('community-ground-rules-dialog')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy suspensions do not invent a reason', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Community(
        teamId: 83,
        communityRepository: StubCommunityRepository(
            banStatus: CommunityBanStatus(
          reason: null,
          endsAt: DateTime.now().add(const Duration(hours: 1)),
        )),
        postRepository: MockPostRepository(posts: const []),
        fixtureRepository: MockFixtureRepository(fixtures: const []),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('커뮤니티 이용이 제한됐어요.'), findsOneWidget);
    expect(find.textContaining('이용규칙을 위반해'), findsNothing);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed suspension lookup is retried on the next visit',
      (tester) async {
    addTearDown(() => mainTabActions.select(0));
    var requests = 0;
    final repository = _ScriptedBanRepository(() async {
      if (++requests == 1) throw StateError('Offline');
      return CommunityBanStatus(
          reason: CommunityBanReason.spam,
          endsAt: DateTime.now().add(const Duration(hours: 1)));
    });
    await tester.pumpWidget(MaterialApp(
        home: Community(
      teamId: 83,
      communityRepository: repository,
      postRepository: MockPostRepository(posts: const []),
      fixtureRepository: MockFixtureRepository(fixtures: const []),
    )));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsNothing);
    mainTabActions.select(0);
    mainTabActions.select(3);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('community-ban-close')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late suspension response does not open a dialog after leaving',
      (tester) async {
    addTearDown(() => mainTabActions.select(0));
    final response = Completer<CommunityBanStatus?>();
    await tester.pumpWidget(MaterialApp(
        home: Community(
      teamId: 83,
      communityRepository: _ScriptedBanRepository(() => response.future),
      postRepository: MockPostRepository(posts: const []),
      fixtureRepository: MockFixtureRepository(fixtures: const []),
    )));
    await tester.pump();
    mainTabActions.select(0);
    response.complete(CommunityBanStatus(
        reason: CommunityBanReason.spam,
        endsAt: DateTime.now().add(const Duration(hours: 1))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('community-ban-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ScriptedBanRepository extends StubCommunityRepository {
  const _ScriptedBanRepository(this.loadStatus);

  final Future<CommunityBanStatus?> Function() loadStatus;

  @override
  Future<CommunityBanStatus?> loadBanStatus() => loadStatus();
}

final _copy = <String,
    ({
  String title,
  String Function(String) body,
  String notice,
  String close
})>{
  'en': (
    title: 'TEMPORARILY SUSPENDED',
    body: (reason) =>
        'Your access to the community has been restricted for $reason.',
    notice:
        'You’ll be able to use the community again when the time above runs out.',
    close: 'Close',
  ),
  'ko': (
    title: '지금은 커뮤니티를 이용할 수 없어요',
    body: (reason) => '$reason 커뮤니티 이용이 제한됐어요.',
    notice: '남은 시간이 지나면 다시 이용할 수 있어요.',
    close: '닫기',
  ),
  'ja': (
    title: '現在、コミュニティを利用できません',
    body: (reason) => '$reasonため、コミュニティの利用が制限されています。',
    notice: '残り時間がなくなると、また利用できます。',
    close: '閉じる',
  ),
  'zh': (
    title: '目前无法使用社区',
    body: (reason) => '因$reason，你的社区使用权限已被限制。',
    notice: '剩余时间结束后，就可以再次使用社区。',
    close: '关闭',
  ),
};

const _reasons = <CommunityBanReason, Map<String, String>>{
  CommunityBanReason.harassment: {
    'en': 'harassing or insulting other users',
    'ko': '다른 이용자를 괴롭히거나 비방해',
    'ja': '他のユーザーに嫌がらせをしたり、誹謗中傷した',
    'zh': '骚扰或辱骂其他用户',
  },
  CommunityBanReason.hateSpeech: {
    'en': 'using hate speech',
    'ko': '혐오 표현을 사용해',
    'ja': 'ヘイトスピーチを使用した',
    'zh': '使用仇恨言论',
  },
  CommunityBanReason.violentLanguage: {
    'en': 'using violent or threatening language',
    'ko': '폭력적인 표현을 사용하거나 위협해',
    'ja': '暴力的な表現を使用したり、脅迫した',
    'zh': '使用暴力或威胁性言论',
  },
  CommunityBanReason.spam: {
    'en': 'repeatedly posting spam',
    'ko': '스팸이나 도배를 반복해',
    'ja': 'スパムや連投を繰り返した',
    'zh': '反复发布垃圾信息或刷屏',
  },
  CommunityBanReason.disruption: {
    'en': 'disrupting community activity',
    'ko': '커뮤니티 활동을 방해해',
    'ja': 'コミュニティ活動を妨害した',
    'zh': '干扰社区正常活动',
  },
  CommunityBanReason.personalInformation: {
    'en': 'sharing someone else’s personal information',
    'ko': '다른 사람의 개인정보를 공개해',
    'ja': '他人の個人情報を公開した',
    'zh': '公开他人的个人信息',
  },
  CommunityBanReason.inappropriateContent: {
    'en': 'posting inappropriate content',
    'ko': '부적절한 콘텐츠를 게시해',
    'ja': '不適切なコンテンツを投稿した',
    'zh': '发布不当内容',
  },
  CommunityBanReason.harmfulToMinors: {
    'en': 'posting content that may be harmful to minors',
    'ko': '미성년자에게 유해한 콘텐츠를 게시해',
    'ja': '未成年者に有害なコンテンツを投稿した',
    'zh': '发布可能对未成年人有害的内容',
  },
  CommunityBanReason.impersonation: {
    'en': 'impersonating another person or organization or misleading others',
    'ko': '다른 사람이나 단체를 사칭하거나 속여',
    'ja': '他人や団体になりすましたり、他者を欺いた',
    'zh': '冒充他人或组织，或欺骗其他用户',
  },
  CommunityBanReason.illegalContent: {
    'en': 'posting or trading illegal content',
    'ko': '불법 콘텐츠를 게시하거나 거래해',
    'ja': '違法なコンテンツを投稿または取引した',
    'zh': '发布或交易非法内容',
  },
  CommunityBanReason.serviceMisuse: {
    'en': 'misusing the service',
    'ko': '서비스를 악용해',
    'ja': 'サービスを不正利用した',
    'zh': '滥用服务',
  },
  CommunityBanReason.guidelinesViolation: {
    'en': 'violating the Community Guidelines',
    'ko': '커뮤니티 이용규칙을 위반해',
    'ja': 'コミュニティガイドラインに違反した',
    'zh': '违反社区准则',
  },
};
