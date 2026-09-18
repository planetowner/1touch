import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/models/community_rules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';

void main() {
  testWidgets('loads and displays rules for the team and device language',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('ko');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
    final response = Completer<CommunityRules>();
    final repository = _ScriptedRulesRepository([() => response.future]);

    await tester.pumpWidget(
      MaterialApp(
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

    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('community-rules-loading')),
      findsOneWidget,
    );
    expect(repository.teamIds, [9]);
    expect(repository.languages, [CommunityLanguage.korean]);

    response.complete(
      CommunityRules(
        language: CommunityLanguage.korean,
        title: '커뮤니티 이용 약속',
        items: const [
          CommunityRule(
            title: '서로 존중해요',
            body: '의견으로 이야기해주세요.',
          ),
        ],
        confirmLabel: '확인했어요',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('커뮤니티 이용 약속'), findsOneWidget);
    expect(find.text('서로 존중해요'), findsOneWidget);
    expect(find.text('의견으로 이야기해주세요.'), findsOneWidget);
    expect(find.text('확인했어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error and retries the same request', (tester) async {
    final repository = _ScriptedRulesRepository([
      () => Future.error(StateError('Unavailable')),
      () => Future.value(
            CommunityRules(
              language: CommunityLanguage.english,
              title: 'Rules from API',
              items: const [
                CommunityRule(title: 'Rule', body: 'Rule body'),
              ],
              confirmLabel: 'Got it',
            ),
          ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
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

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('community-rules-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('community-rules-retry')));
    await tester.pumpAndSettle();

    expect(find.text('Rules from API'), findsOneWidget);
    expect(repository.teamIds, [83, 83]);
    expect(
      repository.languages,
      [CommunityLanguage.english, CommunityLanguage.english],
    );
    expect(tester.takeException(), isNull);
  });
}

class _ScriptedRulesRepository implements CommunityRepository {
  _ScriptedRulesRepository(this._responses);

  final List<Future<CommunityRules> Function()> _responses;
  final List<int> teamIds = [];
  final List<CommunityLanguage> languages = [];
  int _requestIndex = 0;

  @override
  Future<int> loadFollowerCount({required int teamId}) {
    throw UnsupportedError('This test double only scripts rules.');
  }

  @override
  Future<CommunityRules> loadRules({
    required int teamId,
    required CommunityLanguage language,
  }) {
    teamIds.add(teamId);
    languages.add(language);
    return _responses[_requestIndex++]();
  }
}
