import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/interactive_back_page.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('team setup follows the drag and returns to welcome at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final carousel = PageController();
      addTearDown(carousel.dispose);
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/welcome'),
              child: const Text('Login'),
            ),
          ),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/select'),
              child: const Text('Welcome'),
            ),
          ),
        ),
        GoRoute(
          path: '/select',
          pageBuilder: (_, state) => InteractiveBackPage<void>(
            key: state.pageKey,
            child: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: Center(child: Text('Choose teams'))),
                  SizedBox(
                    height: 120,
                    child: Builder(
                      builder: (context) => PageView(
                        key: const ValueKey('team-carousel'),
                        controller: carousel,
                        physics: InteractiveBackDragScope.isDragging(context)
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        children: const [Text('Team A'), Text('Team B')],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        theme: ThemeData(platform: TargetPlatform.iOS),
        routerConfig: router,
      ));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();

      final label = find.text('Choose teams');
      final originalX = tester.getTopLeft(label).dx;
      final start = Offset(size.width / 2, size.height / 2);
      final shortDrag = await tester.startGesture(start);
      await shortDrag.moveBy(const Offset(24, 0));
      await shortDrag.moveBy(Offset(size.width * 0.2, 0));
      await tester.pump();
      expect(
        tester.getTopLeft(label).dx - originalX,
        closeTo(size.width * 0.2 + 24, 1),
      );
      await shortDrag.up();
      await tester.pumpAndSettle();
      expect(label, findsOneWidget);
      expect(tester.getTopLeft(label).dx, closeTo(originalX, 1));

      await tester.drag(
        find.byKey(const ValueKey('team-carousel')),
        Offset(-size.width * 0.7, 0),
      );
      await tester.pumpAndSettle();
      expect(carousel.page, closeTo(1, 0.01));
      expect(label, findsOneWidget);

      final heldDrag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('team-carousel'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await heldDrag.moveBy(Offset(size.width * 0.2, 0));
      await tester.pump();
      expect(
        tester.getTopLeft(label).dx - originalX,
        closeTo(size.width * 0.2, 1),
      );
      await heldDrag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(label).dx, closeTo(originalX, 1));
      expect(carousel.page, closeTo(1, 0.01));

      final verticalDrag = await tester.startGesture(start);
      await verticalDrag.moveBy(const Offset(0, 24));
      await verticalDrag.moveBy(Offset(size.width * 0.2, 0));
      await tester.pump();
      expect(tester.getTopLeft(label).dx, closeTo(originalX, 1));
      await verticalDrag.up();

      final longDrag = await tester.startGesture(Offset(30, size.height / 2));
      await longDrag.moveBy(const Offset(24, 0));
      for (var step = 0; step < 3; step++) {
        await longDrag.moveBy(Offset(size.width * 0.2, 0));
        await tester.pump();
      }
      expect(ModalRoute.of(tester.element(label))!.animation!.value,
          lessThan(0.5));
      await longDrag.up();
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Choose teams'), findsNothing);
      expect(find.text('Login'), findsNothing);
    });
  }
}
