import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/detail_navigation.dart';
import 'package:onetouch/core/notification_navigation.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/team_navigation.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  const shellPaths = ['/home', '/team', '/players', '/community'];
  const destinations = {
    'player': '/players/42',
    'team': '/team/83',
    'match notification': '/match/42?status=live',
    'post notification': '/notifications/post/12',
  };
  final origins = [
    for (final path in [...shellPaths, '/team/11', '/players/1'])
      (base: path, overlay: null),
    for (final path in ['/search', '/profile']) (base: path, overlay: null),
    for (final base in shellPaths)
      for (final overlay in ['/search', '/profile'])
        (base: base, overlay: overlay),
    (base: '/home', overlay: '/match/55'),
  ];

  for (final origin in origins) {
    for (final target in destinations.keys) {
      testWidgets(
          '${origin.base} ${origin.overlay ?? ''} -> $target swipes back '
          'with source state intact', (tester) async {
        final router = _router(origin.base);
        await _mount(tester, router);
        if (origin.overlay != null) {
          router.push(origin.overlay!);
          await tester.pumpAndSettle();
        }
        final source = origin.overlay ?? origin.base;
        final sourceState =
            tester.state<_SourcePageState>(find.byType(_SourcePage));
        await tester.enterText(find.byType(TextField), 'saved search');
        sourceState.scroll.jumpTo(240);
        await tester.pump();

        await tester.tap(find.text('Open $target'));
        await tester.pumpAndSettle();
        expect(find.text(destinations[target]!), findsOneWidget);
        expect(find.text(source), findsNothing);

        await _swipeBack(tester);
        expect(find.text(source), findsOneWidget);
        expect(tester.state(find.byType(_SourcePage)), same(sourceState));
        expect(find.text('saved search'), findsOneWidget);
        expect(sourceState.scroll.offset, 240);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'team, player and notification chains unwind one detail at a time',
      (tester) async {
    final router = _router('/home');
    await _mount(tester, router);
    router.push('/match/55');
    await tester.pumpAndSettle();
    final history = <({String label, State state})>[];
    for (final target in [
      'team',
      'player',
      'match notification',
      'post notification',
      'team',
      'player'
    ]) {
      final page = tester.widget<_SourcePage>(find.byType(_SourcePage));
      history.add(
          (label: page.label, state: tester.state(find.byType(_SourcePage))));
      await tester.tap(find.text('Open $target'));
      await tester.pumpAndSettle();
    }
    for (final previous in history.reversed) {
      await _swipeBack(tester);
      expect(find.text(previous.label), findsOneWidget);
      expect(tester.state(find.byType(_SourcePage)), same(previous.state));
    }
    await _swipeBack(tester);
    expect(find.text('/home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final path in [
    '/players/42/matches',
    '/team/83/standing?competitionId=8'
  ]) {
    testWidgets('$path opened above another detail returns to that detail',
        (tester) async {
      final router = _router('/home');
      await _mount(tester, router);
      await tester.tap(
          find.text('Open ${path.startsWith('/players') ? 'player' : 'team'}'));
      await tester.pumpAndSettle();
      final previous = tester.state(find.byType(_SourcePage));
      openDetailPage(tester.element(find.byType(_SourcePage)), path);
      await tester.pumpAndSettle();
      expect(find.text(path), findsOneWidget);
      await _swipeBack(tester);
      expect(tester.state(find.byType(_SourcePage)), same(previous));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelling the swipe keeps the detail and its source',
      (tester) async {
    final router = _router('/team');
    await _mount(tester, router);
    await tester.tap(find.text('Open player'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(24, 300));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.text('/players/42'), findsOneWidget);
    await _swipeBack(tester);
    expect(find.text('/team'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router(String initialLocation) {
  final root = GlobalKey<NavigatorState>();
  GoRoute detail(String path) => detailRoute(
        rootNavigatorKey: root,
        path: path,
        pageBuilder: (_, state) => MaterialPage<void>(
          key: state.pageKey,
          child: _SourcePage(label: state.uri.toString()),
        ),
      );
  return GoRouter(
      navigatorKey: root,
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(body: shell),
          branches: [
            for (final path in ['/home', '/team', '/players', '/community'])
              StatefulShellBranch(routes: [
                GoRoute(
                  path: path,
                  builder: (_, __) => _SourcePage(label: path),
                  routes: [
                    if (path == '/team' || path == '/players') detail(':id'),
                    if (path == '/team') detail(':id/standing'),
                    if (path == '/players') detail(':id/matches'),
                  ],
                ),
              ]),
          ],
        ),
        for (final path in [
          '/search',
          '/profile',
          '/match/:id',
          '/notifications/post/:id'
        ])
          GoRoute(
            path: path,
            parentNavigatorKey: root,
            builder: (_, state) => _SourcePage(label: state.uri.toString()),
          ),
      ]);
}

Future<void> _mount(WidgetTester tester, GoRouter router) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
    theme: app_style.whitetheme.copyWith(platform: TargetPlatform.iOS),
  ));
  await tester.pumpAndSettle();
}

Future<void> _swipeBack(WidgetTester tester) async {
  await tester.dragFrom(const Offset(24, 300), const Offset(520, 0));
  await tester.pumpAndSettle();
}

class _SourcePage extends StatefulWidget {
  const _SourcePage({required this.label});
  final String label;

  @override
  State<_SourcePage> createState() => _SourcePageState();
}

class _SourcePageState extends State<_SourcePage> {
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Text(widget.label),
          const TextField(),
          Wrap(children: [
            TextButton(
              onPressed: () => openPlayerPage(context, '42'),
              child: const Text('Open player'),
            ),
            TextButton(
              onPressed: () => openTeamPage(context, 83),
              child: const Text('Open team'),
            ),
            for (final notification in {
              'match': '/match/42?status=live',
              'post': '/notifications/post/12',
            }.entries)
              TextButton(
                onPressed: () => NotificationNavigation().open(
                  notification.value,
                  router: GoRouter.of(context),
                  sessionToken: 'current-account',
                  isSessionReady: true,
                ),
                child: Text('Open ${notification.key} notification'),
              ),
          ]),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemExtent: 60,
              itemCount: 40,
              itemBuilder: (_, index) => Text('Row $index'),
            ),
          ),
        ]),
      );
}
