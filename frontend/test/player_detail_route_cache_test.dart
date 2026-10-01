import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/main.dart';
import 'package:onetouch/models/player_detail.dart';

import 'support/player_detail_fixture.dart';

class _CacheRepository implements CachedPlayerDetailRepository {
  final pending = Completer<PlayerDetailSnapshot?>();
  PlayerDetailSnapshot? cached;
  int restores = 0;

  @override
  PlayerDetailSnapshot? snapshotFor(int playerId, {int? seasonId}) => cached;

  @override
  Future<PlayerDetailSnapshot?> restoreFor(int playerId,
      {int? seasonId}) async {
    restores++;
    cached = await pending.future;
    return cached;
  }

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) =>
      throw UnimplementedError();

  @override
  Future<List<PlayerCandidate>> search(String query) =>
      throw UnimplementedError();
}

void main() {
  for (final path in ['/players/1', '/match-player/1']) {
    testWidgets('$path waits for local detail before opening', (tester) async {
      final repository = _CacheRepository();
      final router = GoRouter(initialLocation: '/start', routes: [
        GoRoute(
          path: '/start',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.go(path),
              child: const Text('Open player'),
            ),
          ),
        ),
        GoRoute(
          path: path.replaceFirst('/1', '/:playerId'),
          redirect: (_, state) async {
            await restorePlayerDetailBeforeNavigation(
              state.pathParameters['playerId'],
              repository: repository,
            );
            return null;
          },
          builder: (_, __) => Scaffold(
            body: Text(repository.cached == null ? 'No cache' : 'Cached'),
          ),
        ),
      ]);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open player'));
      await tester.pump();
      expect(find.text('Cached'), findsNothing);

      repository.pending.complete(
        PlayerDetailSnapshot(detailFixture(), DateTime.now().toUtc()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cached'), findsOneWidget);
      expect(repository.restores, 1);
    });
  }

  test('already restored detail skips disk read', () async {
    final repository = _CacheRepository()
      ..cached = PlayerDetailSnapshot(detailFixture(), DateTime.now().toUtc());
    await restorePlayerDetailBeforeNavigation('1', repository: repository);
    expect(repository.restores, 0);
  });

  test('cache miss and read failure never block navigation', () async {
    final missing = _CacheRepository()..pending.complete(null);
    await restorePlayerDetailBeforeNavigation('1', repository: missing);
    expect(missing.restores, 1);

    final broken = _CacheRepository()
      ..pending.completeError(StateError('Disk unavailable'));
    await restorePlayerDetailBeforeNavigation('1', repository: broken);
    expect(broken.restores, 1);
  });
}
