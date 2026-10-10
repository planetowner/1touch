import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/models/team_best_eleven.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  testWidgets('goalkeeper boxes follow the 345 by 392 pitch design',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 345,
            child: RepaintBoundary(
              key: boundaryKey,
              child: BestElevenPitch(
                teamId: 503,
                formation: '4-3-3',
                players: const [
                  BestElevenEntry(
                    slotKey: '1:1',
                    slotIndex: 0,
                    playerId: 1,
                    playerName: 'Keeper',
                    starts: 1,
                    jerseyNumber: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('team-best-eleven-card')),
    );
    expect((card.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(24));
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes =
          (await picture.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      int redAt(int x, int y) => bytes.getUint8((y * picture.width + x) * 4);
      expect(picture.width, 690);
      expect(picture.height, 784);
      // 두 박스의 왼쪽 선이 각각 x=73, x=113에 그려져야 해요.
      expect(redAt(145, 600), greaterThan(redAt(160, 600)));
      expect(redAt(225, 740), greaterThan(redAt(240, 740)));
      picture.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
