import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/media/asset_media_picker.dart';
import 'package:onetouch/features/media/avatar_picker_screen.dart';
import 'package:onetouch/features/media/native_avatar_header.dart';

void main() {
  const channel = MethodChannel('onetouch/media_picker');
  late Directory directory;
  late List<Map<String, Object>> selection;
  final calls = <MethodCall>[];

  setUp(() {
    directory = Directory.systemTemp.createTempSync('media_picker_test_');
    selection = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return selection;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    directory.deleteSync(recursive: true);
    calls.clear();
  });

  Future<BuildContext> mountPicker(WidgetTester tester,
      {NavigatorObserver? observer}) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      navigatorObservers: [if (observer != null) observer],
      home: Builder(builder: (value) {
        context = value;
        return const SizedBox();
      }),
    ));
    return context;
  }

  testWidgets('keeps full photos, video type and native selection order',
      (tester) async {
    final context = await mountPicker(tester);
    await tester.runAsync(() async {
      final portrait = await _photo(directory, 90, 160);
      final landscape = await _photo(directory, 160, 90);
      final video = File('${directory.path}/clip.m4v')
        ..writeAsBytesSync([1, 2, 3]);
      selection = [
        {'path': portrait.path, 'mimeType': 'image/png'},
        {'path': video.path, 'mimeType': 'video/mp4'},
        {'path': landscape.path, 'mimeType': 'image/png'},
      ];

      final files = await pickAssetMedia(context, maxAssets: 3);

      expect(calls.single.method, 'pick');
      expect(calls.single.arguments, {'maxAssets': 3, 'imagesOnly': false});
      expect(files.map((file) => file.path),
          [portrait.path, video.path, landscape.path]);
      expect(files[1].mimeType, 'video/mp4');
      for (final (index, size) in [
        (0, const Size(90, 160)),
        (2, const Size(160, 90)),
      ]) {
        final bytes = await files[index].readAsBytes();
        expect(bytes, await (index == 0 ? portrait : landscape).readAsBytes());
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(
            Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
            size);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });

  testWidgets('one remaining attachment still allows a video', (tester) async {
    final context = await mountPicker(tester);
    selection = [
      {'path': '/cache/clip.mov', 'mimeType': 'video/quicktime'}
    ];

    final files = await pickAssetMedia(context, maxAssets: 1);

    expect(calls.single.arguments, {'maxAssets': 1, 'imagesOnly': false});
    expect(files.single.mimeType, 'video/quicktime');
  });

  testWidgets('cancelling the post picker returns no media', (tester) async {
    final context = await mountPicker(tester);

    expect(await pickAssetMedia(context, maxAssets: 10), isEmpty);
  });

  testWidgets('native export errors reach the existing screen error handling',
      (tester) async {
    final context = await mountPicker(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'picker_failed');
    });

    await expectLater(pickAssetMedia(context, maxAssets: 2),
        throwsA(isA<PlatformException>()));
  });

  testWidgets('profile opens the shared picker and cancel returns no file',
      (tester) async {
    final context = await mountPicker(tester);
    final pending = pickAvatarImage(context);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AvatarPickerScreen), findsOneWidget);
    expect(calls, isEmpty);
    tester
        .widget<NativeAvatarHeader>(find.byType(NativeAvatarHeader))
        .onCancel!();
    await tester.pumpAndSettle();
    expect(await pending, isNull);
  });
}

Future<File> _photo(Directory directory, int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.blue);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return File('${directory.path}/$width-$height.png')
      .writeAsBytes(bytes!.buffer.asUint8List());
}
