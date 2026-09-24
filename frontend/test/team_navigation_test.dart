import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/team_navigation.dart';

void main() {
  setUpAppCatalog();
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
                  path: '/players',
                  builder: (_, __) => const Text('Players'),
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
    expect(find.text('Selected branch 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unsupported opponent cannot open a Team page',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, _) => Material(
            child: TextButton(
              onPressed: () => openTeamPage(context, 999999),
              child: const Text('Open unsupported team'),
            ),
          ),
        ),
        GoRoute(
          path: '/team/:id',
          builder: (_, state) => Text('Team ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open unsupported team'));
    await tester.pumpAndSettle();

    expect(find.text('Open unsupported team'), findsOneWidget);
    expect(find.text('Team 999999'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('direct Team routes redirect when the team is unsupported', () {
    expect(redirectUnsupportedTeamPath('83'), isNull);
    expect(redirectUnsupportedTeamPath('999999'), '/home');
    expect(redirectUnsupportedTeamPath('not-an-id'), '/home');
  });
}
