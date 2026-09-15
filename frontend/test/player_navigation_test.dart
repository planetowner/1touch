import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/player_navigation.dart';

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
                  path: '/team',
                  builder: (_, __) => const Text('Team'),
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
    expect(find.text('Selected branch 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
