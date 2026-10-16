import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/media/asset_media_picker.dart';
import 'package:onetouch/features/media/media_library.dart';
import 'package:onetouch/features/media/media_picker_screen.dart';
import 'package:onetouch/features/media/media_picker_header.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const libraryChannel = MethodChannel('com.fluttercandies/photo_manager');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(libraryChannel, (call) async {
      if (call.method == 'requestPermissionExtend') {
        return PermissionState.denied.index;
      }
      throw PlatformException(code: 'unexpected_library_call');
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(libraryChannel, null));

  Future<BuildContext> mountPicker(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      home: Builder(builder: (value) {
        context = value;
        return const SizedBox();
      }),
    ));
    return context;
  }

  for (final maximum in [1, 3]) {
    testWidgets(
        'posts open the shared media picker with $maximum remaining slots',
        (tester) async {
      final context = await mountPicker(tester);
      final pending = pickAssetMedia(context, maxAssets: maximum);
      await tester.pumpAndSettle();
      final screen =
          tester.widget<MediaPickerScreen>(find.byType(MediaPickerScreen));
      expect(screen.cropAvatar, false);
      expect(screen.maxAssets, maximum);
      expect(screen.library.type, RequestType.common);
      expect(find.text('Photos & Videos'), findsOneWidget);

      final files = [
        XFile('/cache/clip.mov', mimeType: 'video/quicktime'),
        if (maximum > 1) XFile('/cache/portrait.png', mimeType: 'image/png'),
      ];
      Navigator.of(tester.element(find.byType(MediaPickerScreen))).pop(files);
      await tester.pumpAndSettle();
      expect(await pending, same(files));
    });
  }

  testWidgets('cancelling the post picker returns no attachments',
      (tester) async {
    final context = await mountPicker(tester);
    final pending = pickAssetMedia(context, maxAssets: 10);
    await tester.pumpAndSettle();
    tester
        .widget<MediaPickerHeader>(find.byType(MediaPickerHeader))
        .onCancel!();
    await tester.pumpAndSettle();
    expect(await pending, isEmpty);
  });

  testWidgets('profile keeps image-only cropping and cancel returns no file',
      (tester) async {
    final context = await mountPicker(tester);
    final pending = pickAvatarImage(context);
    await tester.pumpAndSettle();
    final screen =
        tester.widget<MediaPickerScreen>(find.byType(MediaPickerScreen));
    expect(screen.cropAvatar, true);
    expect(screen.library.type, RequestType.image);
    tester
        .widget<MediaPickerHeader>(find.byType(MediaPickerHeader))
        .onCancel!();
    await tester.pumpAndSettle();
    expect(await pending, isNull);
  });

  test('attachment export keeps original bytes and the native MIME type',
      () async {
    final directory = await Directory.systemTemp.createTemp('media-export-');
    try {
      for (final mime in ['image/png', 'image/gif', 'video/quicktime']) {
        final bytes = [1, 2, 3, 4];
        final original =
            await File('${directory.path}/source').writeAsBytes(bytes);
        final asset = _OriginalAsset(original, mime);
        final result = await const MediaLibrary(type: RequestType.common)
            .attachment(asset);
        expect(result.path, original.path);
        expect(result.mimeType, mime);
        expect(await result.readAsBytes(), bytes);
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

class _OriginalAsset extends AssetEntity {
  _OriginalAsset(this.original, this.nativeMimeType)
      : super(
            id: 'original',
            typeInt: nativeMimeType.startsWith('video/') ? 2 : 1,
            width: 90,
            height: 160);
  final File original;
  final String nativeMimeType;

  @override
  Future<File?> get originFile async => original;
  @override
  Future<String?> get mimeTypeAsync async => nativeMimeType;
  @override
  Future<File?> get file =>
      throw StateError('Attachments must use the full original file');
}
