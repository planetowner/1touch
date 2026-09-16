import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/screens/CommunityScreen.dart';
import 'package:onetouch/models/community_rules.dart';

void main() {
  testWidgets('shows the repository-provided follower count', (tester) async {
    final repository = _ScriptedCommunityRepository([
      () => Future.value(1250),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Community(
          teamId: 9,
          postRepository: MockPostRepository(),
          communityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.3K Followers'), findsOneWidget);
    expect(repository.teamIds, [9]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reloads for a new team and ignores the stale count',
      (tester) async {
    final first = Completer<int>();
    final second = Completer<int>();
    final repository = _ScriptedCommunityRepository([
      () => first.future,
      () => second.future,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Community(
          teamId: 9,
          postRepository: MockPostRepository(),
          communityRepository: repository,
        ),
      ),
    );
    expect(find.text('Followers'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Community(
          teamId: 83,
          postRepository: MockPostRepository(),
          communityRepository: repository,
        ),
      ),
    );
    second.complete(42);
    await tester.pumpAndSettle();
    expect(find.text('42 Followers'), findsOneWidget);

    first.complete(999);
    await tester.pumpAndSettle();
    expect(find.text('42 Followers'), findsOneWidget);
    expect(find.text('999 Followers'), findsNothing);
    expect(repository.teamIds, [9, 83]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not invent a count when the request fails', (tester) async {
    final repository = _ScriptedCommunityRepository([
      () => Future<int>.error(StateError('Unavailable')),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Community(
          teamId: 9,
          postRepository: MockPostRepository(),
          communityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Followers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ScriptedCommunityRepository implements CommunityRepository {
  _ScriptedCommunityRepository(this._responses);

  final List<Future<int> Function()> _responses;
  final List<int> teamIds = [];
  int _requestIndex = 0;

  @override
  Future<int> loadFollowerCount({required int teamId}) {
    teamIds.add(teamId);
    return _responses[_requestIndex++]();
  }

  @override
  Future<CommunityRules> loadRules({
    required int teamId,
    required CommunityLanguage language,
  }) {
    throw UnsupportedError('This test double only scripts follower counts.');
  }
}
