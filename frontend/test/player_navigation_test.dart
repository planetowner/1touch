import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/features/PlayerScreenFeatures.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_detail.dart';

void main() {
  testWidgets('opening a player outside the shell selects the Players branch',
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
    expect(find.text('Selected branch 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking row opens its player', (tester) async {
    final player = playerRepository.ranking.first;
    final router = GoRouter(
      initialLocation: '/showcase',
      routes: [
        GoRoute(
          path: '/showcase',
          builder: (_, __) => Scaffold(
            body: PlayerRankingBox(players: [player]),
          ),
        ),
        GoRoute(
          path: '/players/:id',
          builder: (_, state) => Text('Player ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(ValueKey('ranking-player-${player.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Player ${player.id}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full ranking row opens its player', (tester) async {
    final player = playerRepository.ranking.first;
    final router = GoRouter(
      initialLocation: '/ranking',
      routes: [
        GoRoute(
          path: '/ranking',
          builder: (_, __) => const FullRankingPopup(),
        ),
        GoRoute(
          path: '/players/:id',
          builder: (_, state) => Text('Player ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(ValueKey('full-ranking-player-${player.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Player ${player.id}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one to watch card opens its player', (tester) async {
    final player = playerRepository.onesToWatch.first;
    final router = GoRouter(
      initialLocation: '/showcase',
      routes: [
        GoRoute(
          path: '/showcase',
          builder: (_, __) => Scaffold(
            body: OnesToWatchCard(player: player),
          ),
        ),
        GoRoute(
          path: '/players/:id',
          builder: (_, state) => Text('Player ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.byKey(ValueKey('ones-to-watch-player-${player.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Player ${player.id}'), findsOneWidget);
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
