import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/page_refresh.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final steps in [4, 24]) {
      testWidgets('Home and tabs share pull/release motion: $platform, $steps',
          (tester) async {
        final home = await _measurePull(tester,
            platform: platform, steps: steps, nested: false);
        for (final headerHeight in [80.0, 240.0]) {
          final nested = await _measurePull(tester,
              platform: platform,
              steps: steps,
              nested: true,
              headerHeight: headerHeight);
          expect(nested.samples, home.samples,
              reason: 'header height $headerHeight');
          expect(nested.refreshes, steps == 4 ? 0 : 1);
        }
        expect(home.refreshes, steps == 4 ? 0 : 1);
      });
    }
    testWidgets('scrolling back to the top does not refresh: $platform',
        (tester) async {
      for (final nested in [false, true]) {
        final result = await _measurePull(tester,
            platform: platform, steps: 24, nested: nested, initialOffset: 60);
        expect(result.refreshes, 0, reason: 'nested: $nested');
      }
    });
  }
}

Future<({List<String> samples, int refreshes})> _measurePull(
  WidgetTester tester, {
  required bool nested,
  required TargetPlatform platform,
  required int steps,
  double headerHeight = 120,
  double initialOffset = 0,
}) async {
  final refresh = Completer<void>();
  var refreshes = 0;
  final samples = <String>[];
  const markerKey = ValueKey('motion-marker');
  final header =
      SliverAppBar(toolbarHeight: headerHeight, floating: true, snap: true);
  const content = SizedBox(key: markerKey, height: 1400);
  final controller = ScrollController(initialScrollOffset: initialOffset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: PageRefreshIndicator(
        onRefresh: () {
          refreshes++;
          return refresh.future;
        },
        notificationDepth: nested ? 2 : 0,
        builder: (context, physics) => nested
            ? DefaultTabController(
                length: 1,
                child: NestedScrollView(
                  controller: controller,
                  physics: physics,
                  headerSliverBuilder: (_, __) => [header],
                  body: TabBarView(children: [
                    ListView(
                      children: const [content],
                    ),
                  ]),
                ),
              )
            : CustomScrollView(
                controller: controller,
                physics: physics,
                slivers: [header, const SliverToBoxAdapter(child: content)],
              ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  final start = tester.getTopLeft(find.byKey(markerKey)).dy;
  void sample(String label) {
    final indicator = find.byType(RefreshProgressIndicator);
    final visible = indicator.evaluate().isNotEmpty;
    final value = visible
        ? tester.widget<RefreshProgressIndicator>(indicator).value
        : null;
    final indicatorTop = visible ? tester.getTopLeft(indicator).dy : null;
    final bounds = tester.getRect(find.byKey(markerKey));
    samples.add('$label: ${(bounds.top - start).toStringAsFixed(2)} / '
        '${bounds.height.toStringAsFixed(2)} / '
        '${value?.toStringAsFixed(4)} / ${indicatorTop?.toStringAsFixed(2)}');
  }

  final gesture = await tester.startGesture(const Offset(200, 300));
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 16));
    sample('pull $i');
  }
  await gesture.up();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 32));
    sample('release $i');
  }
  refresh.complete();
  await tester.pumpAndSettle();
  await tester.pumpWidget(const SizedBox());
  controller.dispose();
  return (samples: samples, refreshes: refreshes);
}
