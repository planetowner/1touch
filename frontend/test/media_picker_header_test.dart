import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/media/media_picker_header.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform header actions remain disabled while saving',
        (tester) async {
      var cancelled = 0;
      var confirmed = 0;
      Future<void> mount({bool saving = false}) =>
          tester.pumpWidget(MaterialApp(
            theme: darktheme.copyWith(platform: platform),
            home: Scaffold(
              body: MediaPickerHeader(
                onCancel: saving ? null : () => cancelled++,
                onDone: saving ? null : () => confirmed++,
                saving: saving,
              ),
            ),
          ));

      await mount();
      await tester.pumpAndSettle();
      final cancel = find.byKey(const ValueKey('media-picker-cancel'));
      final done = find.byKey(const ValueKey('media-picker-done'));
      final title = find.text('Profile Photo');
      expect(tester.getCenter(title).dy, tester.getCenter(cancel).dy);
      expect(tester.getCenter(title).dy, tester.getCenter(done).dy);
      await tester.tap(cancel);
      await tester.tap(done);
      expect(cancelled, 1);
      expect(confirmed, 1);

      await mount(saving: true);
      await tester.pump();
      await tester.tap(cancel);
      await tester.tap(done);
      expect(cancelled, 1);
      expect(confirmed, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
