import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('loading football stays centered at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: FootballLoadingIndicator())),
      ));
      final loader = find.byType(FootballLoadingIndicator);
      expect(tester.getSize(loader), const Size(56, 56));
      expect(tester.getCenter(loader), tester.getCenter(find.byType(Scaffold)));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading football is 56px and rotates in its content area',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: FootballLoadingIndicator())),
    ));
    final loader = find.byType(FootballLoadingIndicator);
    expect(tester.getSize(loader), const Size(56, 56));
    expect(tester.getCenter(loader), tester.getCenter(find.byType(Scaffold)));

    double rotation() => tester
        .widget<Transform>(
            find.byKey(const ValueKey('football-loading-motion')))
        .transform
        .storage[0];
    final start = rotation();
    await tester.pump(const Duration(milliseconds: 400));
    expect(rotation(), isNot(start));
  });

  testWidgets('loading football respects reduced motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: FootballLoadingIndicator())),
      ),
    ));
    await tester.pump(const Duration(seconds: 4));
    final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('football-loading-motion')));
    expect(transform.transform.storage[0], closeTo(1, 0.01));
  });
}
