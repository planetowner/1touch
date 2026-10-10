import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/core/team_navigation.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  testWidgets('team and player opened from a match pop back to that match',
      (tester) async {
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    var matchCreates = 0;
    final router = GoRouter(
      initialLocation: '/home',
      navigatorKey: rootNavigatorKey,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, navigationShell) => Scaffold(
            body: navigationShell,
            bottomNavigationBar: Text(
              'Selected branch ${navigationShell.currentIndex}',
            ),
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/home',
                builder: (context, _) => TextButton(
                  onPressed: () => context.push('/match/55?status=live'),
                  child: const Text('Open match'),
                ),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/team', builder: (_, __) => const Text('Team tab')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/players',
                  builder: (_, __) => const Text('Players tab')),
            ]),
          ],
        ),
        GoRoute(
          path: '/match/:matchId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, state) => _TestMatchPage(
            matchId: state.pathParameters['matchId']!,
            onCreated: () => matchCreates++,
          ),
        ),
        GoRoute(
          path: '/team/:teamId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text('Team ${state.pathParameters['teamId']}'),
                TextButton(
                  onPressed: () => openPlayerPage(context, '2'),
                  child: const Text('Open player from team'),
                ),
                if (state.pathParameters['teamId'] == '83')
                  TextButton(
                    onPressed: () => openTeamPage(context, 11),
                    child: const Text('Open another team'),
                  ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/players/:playerId',
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text('Player ${state.pathParameters['playerId']}'),
                if (state.pathParameters['playerId'] == '9967153')
                  TextButton(
                    onPressed: () => openPlayerPage(context, '2'),
                    child: const Text('Open another player'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Open match'));
    await tester.pumpAndSettle();
    expect(find.text('Match 55'), findsOneWidget);

    await tester.tap(find.text('Open team'));
    await tester.pumpAndSettle();
    expect(find.text('Team 83'), findsOneWidget);
    expect(router.canPop(), isTrue);
    await tester.tap(find.text('Open another team'));
    await tester.pumpAndSettle();
    expect(find.text('Team 11'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Team 83'), findsOneWidget);
    await tester.tap(find.text('Open player from team'));
    await tester.pumpAndSettle();
    expect(find.text('Player 2'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Team 83'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Match 55'), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(matchCreates, 1);

    await tester.tap(find.text('Open player'));
    await tester.pumpAndSettle();
    expect(find.text('Player 9967153'), findsOneWidget);
    expect(router.canPop(), isTrue);
    await tester.tap(find.text('Open another player'));
    await tester.pumpAndSettle();
    expect(find.text('Player 2'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Player 9967153'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Match 55'), findsOneWidget);
    expect(matchCreates, 1);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Open match'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestMatchPage extends StatefulWidget {
  const _TestMatchPage({required this.matchId, required this.onCreated});

  final String matchId;
  final VoidCallback onCreated;

  @override
  State<_TestMatchPage> createState() => _TestMatchPageState();
}

class _TestMatchPageState extends State<_TestMatchPage> {
  @override
  void initState() {
    super.initState();
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Text('Match ${widget.matchId}'),
            TextButton(
              onPressed: () => openTeamPage(context, 83),
              child: const Text('Open team'),
            ),
            TextButton(
              onPressed: () => openPlayerPage(context, '9967153'),
              child: const Text('Open player'),
            ),
          ],
        ),
      );
}
