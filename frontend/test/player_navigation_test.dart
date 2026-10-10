import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/detail_navigation.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/player/player_directory_sheets.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_detail.dart';

import 'support/app_catalog.dart';
import 'support/player_directory_fixture.dart';
import 'support/player_detail_fixture.dart';

void main() {
  setUpAppCatalog();
  testWidgets('opening a player outside the shell returns to its source',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, _) => Material(
            child: TextButton(
              onPressed: () => openPlayerPage(context, 'lee-kang-in'),
              child: const Text('Open player'),
            ),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, _, navigationShell) => Scaffold(
            body: navigationShell,
            bottomNavigationBar: Text(
              'Selected branch ${navigationShell.currentIndex}',
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, __) => const Text('Home'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/team',
                  builder: (_, __) => const Text('Team'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/players',
                  builder: (_, __) => const Text('Players'),
                  routes: [
                    GoRoute(
                      path: ':id',
                      builder: (_, state) => Text(
                        'Player ${state.pathParameters['id']}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/community',
                  builder: (_, __) => const Text('Community'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open player'));
    await tester.pumpAndSettle();

    expect(find.text('Player lee-kang-in'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Open player'), findsOneWidget);
    expect(find.text('Player lee-kang-in'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (name, rowKey) in [
    ('ranking', 'ranking-player-1'),
    ('full ranking', 'full-ranking-player-1'),
    ('one to watch', 'ones-to-watch-player-1'),
  ]) {
    testWidgets('$name opens its player', (tester) async {
      final repository = FakePlayerDirectoryRepository();
      final ranking = await repository.ranking();
      final Widget page;
      if (name == 'ranking') {
        page = PlayerRankingPanel(repository: repository);
      } else if (name == 'full ranking') {
        page = PlayerFullRankingSheet(
          players: ranking.items,
          followingController: null,
          detailRepository: FakePlayerDetailRepository(),
        );
      } else {
        page = PlayersToWatch(repository: repository);
      }
      final router = GoRouter(
        initialLocation: '/showcase',
        routes: [
          GoRoute(
            path: '/showcase',
            builder: (_, __) => Scaffold(body: page),
          ),
          GoRoute(
            path: '/players/:id',
            builder: (_, state) => Text('Player ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(rowKey)));
      await tester.pumpAndSettle();

      expect(find.text('Player 1'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(rowKey)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('full ranking popup stays open after swiping back from a player',
      (tester) async {
    final root = GlobalKey<NavigatorState>();
    final repository = FakePlayerDirectoryRepository();
    final router = GoRouter(
      navigatorKey: root,
      initialLocation: '/players',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/players',
                builder: (_, __) => Scaffold(
                  body: SingleChildScrollView(
                    child: PlayerRankingPanel(
                      repository: repository,
                      detailRepository: FakePlayerDetailRepository(),
                    ),
                  ),
                ),
                routes: [
                  detailRoute(
                    rootNavigatorKey: root,
                    path: ':id',
                    pageBuilder: (_, state) => MaterialPage<void>(
                      key: state.pageKey,
                      child: Scaffold(
                        body: Center(
                            child:
                                Text('Player ${state.pathParameters['id']}')),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: app_style.whitetheme.copyWith(platform: TargetPlatform.iOS),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('See all'));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    final sheetState = tester.state(find.byType(PlayerFullRankingSheet));
    await tester.tap(find.byKey(const ValueKey('full-ranking-player-1')));
    await tester.pumpAndSettle();
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.byType(PlayerFullRankingSheet), findsNothing);
    await tester.dragFrom(const Offset(24, 300), const Offset(520, 0));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(PlayerFullRankingSheet)), same(sheetState));
    expect(find.byKey(const ValueKey('full-ranking-player-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed player match opens the past match route',
      (tester) async {
    final match = PlayerDetailMatch(
      id: 123,
      date: DateTime.utc(2026, 9, 20),
      live: false,
      competition: 'Premier League',
      round: '5',
      opponent: 'Opponent',
      opponentImage: null,
      result: 'W',
      homeScore: 2,
      awayScore: 1,
      rating: 8,
      metrics: const [],
    );
    final router = GoRouter(
      initialLocation: '/showcase',
      routes: [
        GoRoute(
          path: '/showcase',
          builder: (_, __) => Scaffold(
            body: PlayerDetailMatchCard(match: match),
          ),
        ),
        GoRoute(
          path: '/match/:id',
          builder: (_, state) => Text(
            'Match ${state.pathParameters['id']} '
            '${state.uri.queryParameters['status']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byType(PlayerDetailMatchCard));
    await tester.pumpAndSettle();

    expect(find.text('Match 123 past'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
