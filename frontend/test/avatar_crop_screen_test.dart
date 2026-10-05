import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/media/avatar_crop_screen.dart';

void main() {
  const channel = MethodChannel('plugins.legoffmael.dev/insta_assets_crop');
  late Directory directory;
  late File original;
  final calls = <String>[];

  setUp(() {
    directory = Directory.systemTemp.createTempSync('avatar_crop_test_');
    original = File('${directory.path}/avatar.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return original.path;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
    calls.clear();
  });

  Future<void> openCrop(WidgetTester tester, Size screenSize,
      void Function(XFile?) onResult) async {
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          return TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<XFile>(
                MaterialPageRoute(
                  builder: (_) => AvatarCropScreen(
                    originalFile: original,
                    imageSize: const Size(1200, 800),
                    image: const ColoredBox(color: Colors.blue),
                  ),
                ),
              );
              onResult(result);
            },
            child: const Text('OPEN'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarCropScreen), findsOneWidget);
    final save = tester.widget<TextButton>(
      find.byKey(const ValueKey('avatar-crop-save')),
    );
    expect(save.style?.foregroundColor?.resolve({}), Colors.white);
    expect(tester.takeException(), isNull);
  }

  testWidgets('cancel on a compact screen returns without exporting',
      (tester) async {
    var returned = false;
    await openCrop(tester, const Size(320, 568), (result) {
      returned = true;
      expect(result, isNull);
    });

    await tester.tap(find.byKey(const ValueKey('avatar-crop-cancel')));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save on a tall screen returns the cropped file', (tester) async {
    XFile? result;
    await openCrop(tester, const Size(430, 932), (value) => result = value);

    await tester.tap(find.byKey(const ValueKey('avatar-crop-save')));
    await tester.pumpAndSettle();

    expect(calls, ['sampleImage', 'cropImage']);
    expect(result?.path, original.path);
    expect(tester.takeException(), isNull);
  });
}
