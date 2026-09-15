import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/team_navigation.dart';

void main() {
  testWidgets('opening a team outside the shell selects the Team branch',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, _) => Material(
            child: TextButton(
              onPressed: () => openTeamPage(context, 83),
              child: const Text('Open Barcelona'),
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
                ),
              ],
            ),
            StatefulShellBranch(
              initialLocation: '/team/83',
              routes: [
                GoRoute(
                  path: '/team/:id',
                  builder: (_, state) => Text(
                    'Team ${state.pathParameters['id']}',
                  ),
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
    await tester.tap(find.text('Open Barcelona'));
    await tester.pumpAndSettle();

    expect(find.text('Team 83'), findsOneWidget);
    expect(find.text('Selected branch 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
