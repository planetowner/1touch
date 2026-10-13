import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_close_header.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final iconSize in [24.0, 28.0]) {
      testWidgets('close icon has 24px right inset at $size / $iconSize',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var closed = false;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: AppCloseHeader(
                title: 'Following Players',
                iconSize: iconSize,
                onClose: () => closed = true,
              ),
            ),
          ),
        ));

        final icon = tester.getRect(find.byIcon(Icons.close));
        final button = tester.getRect(find.byType(IconButton));
        expect(size.width - icon.right, 24);
        expect(button.size, const Size(48, 48));
        expect(tester.getCenter(find.text('Following Players')).dx,
            size.width / 2);
        await tester.tapAt(Offset(button.left + 2, button.center.dy));
        expect(closed, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
