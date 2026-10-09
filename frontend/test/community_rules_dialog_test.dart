import 'package:onetouch/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/stub_community_repository.dart';
import 'package:onetouch/models/community_rules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ground_rules.dart';

void main() {
  testWidgets('loads and displays rules for the team and device language',
      (tester) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ko')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    final response = Completer<CommunityRules>();
    final repository = _ScriptedRulesRepository([() => response.future]);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        localeListResolutionCallback: resolveAppLocale,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGroundRulesModal(
              context,
              teamId: 9,
              repository: repository,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('community-rules-loading')),
      findsOneWidget,
    );
    expect(repository.teamIds, [9]);

    response.complete(
      CommunityRules(
        title: 'Community Ground Rules',
        items: const [
          CommunityRule(
            title: 'Keep it about football',
            body: 'Disagree with the take, not the person.',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('커뮤니티 이용 약속'), findsOneWidget);
    expect(find.text('의견이 달라도 서로 존중해요'), findsOneWidget);
    expect(find.text('생각이 달라도 상대방을 공격하지 말고, 의견으로 이야기해주세요.'), findsOneWidget);
    expect(find.text('이해했습니다!'), findsOneWidget);
    expect(find.text('확인했어요'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'en': 'Keep it about football',
    'ko': '의견이 달라도 서로 존중해요',
    'ja': '意見が違っても、お互いを尊重しましょう',
    'zh': '尊重不同观点，倡导理性交流',
  }.entries) {
    testWidgets('translates the same community rule keys into ${entry.key}',
        (tester) async {
      final repository = _ScriptedRulesRepository([
        () async =>
            CommunityRules(title: 'Community Ground Rules', items: const [
              CommunityRule(
                  title: 'Keep it about football',
                  body: 'Disagree with the take, not the person.'),
            ]),
      ]);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(entry.key),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Builder(
            builder: (context) => TextButton(
                  onPressed: () => showGroundRulesModal(context,
                      teamId: 9, repository: repository),
                  child: const Text('Open'),
                )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows an error and retries the same request', (tester) async {
    final repository = _ScriptedRulesRepository([
      () => Future.error(StateError('Unavailable')),
      () => Future.value(
            CommunityRules(
              title: 'Rules from API',
              items: const [
                CommunityRule(title: 'Rule', body: 'Rule body'),
              ],
            ),
          ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        localeListResolutionCallback: resolveAppLocale,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGroundRulesModal(
              context,
              teamId: 83,
              repository: repository,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('community-rules-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('community-rules-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Rules from API'), findsOneWidget);
    expect(find.text('I UNDERSTAND!'), findsOneWidget);
    expect(find.text('Got it'), findsNothing);
    expect(repository.teamIds, [83, 83]);
    expect(tester.takeException(), isNull);
  });
}

class _ScriptedRulesRepository extends StubCommunityRepository {
  _ScriptedRulesRepository(this._responses);

  final List<Future<CommunityRules> Function()> _responses;
  final List<int> teamIds = [];
  int _requestIndex = 0;

  @override
  Future<int> loadFollowerCount({required int teamId}) {
    throw UnsupportedError('This test double only scripts rules.');
  }

  @override
  Future<CommunityRules> loadRules({
    required int teamId,
  }) {
    teamIds.add(teamId);
    return _responses[_requestIndex++]();
  }
}
