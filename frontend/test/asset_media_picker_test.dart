import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insta_assets_picker/insta_assets_picker.dart';
import 'package:onetouch/features/media/asset_media_picker.dart';

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('post_media_picker_test_');
  });
  tearDown(() {
    AssetPicker.setPickerDelegate(const AssetPickerDelegate());
    directory.deleteSync(recursive: true);
  });

  Future<BuildContext> mountPicker(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    return context;
  }

  testWidgets('keeps whole portrait and landscape photos and selection order',
      (tester) async {
    final context = await mountPicker(tester);
    await tester.runAsync(() async {
      final portrait = await _photo(directory, 90, 160);
      final landscape = await _photo(directory, 160, 90);
      final video = File('${directory.path}/clip.mp4')
        ..writeAsBytesSync([1, 2, 3]);
      final picker = _Picker([
        _Asset(AssetType.image, fullSizeFile: portrait),
        _Asset(AssetType.video, originalFile: video),
        _Asset(AssetType.image, fullSizeFile: landscape),
      ]);
      AssetPicker.setPickerDelegate(picker);

      final files = await pickAssetMedia(context, maxAssets: 3);

      expect(picker.config?.maxAssets, 3);
      expect(picker.config?.requestType, RequestType.common);
      expect(files.map((file) => file.path),
          [portrait.path, video.path, landscape.path]);
      expect(files[1].mimeType, 'video/*');
      for (final (index, size) in [
        (0, const Size(90, 160)),
        (2, const Size(160, 90)),
      ]) {
        final bytes = await files[index].readAsBytes();
        final source = index == 0 ? portrait : landscape;
        expect(bytes, await source.readAsBytes());
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

  testWidgets('cancelling selection returns no attachments', (tester) async {
    final context = await mountPicker(tester);
    AssetPicker.setPickerDelegate(_Picker(null));

    expect(await pickAssetMedia(context, maxAssets: 10), isEmpty);
  });

  testWidgets('a missing photo fails instead of returning partial attachments',
      (tester) async {
    final context = await mountPicker(tester);
    AssetPicker.setPickerDelegate(_Picker([_Asset(AssetType.image)]));

    await expectLater(pickAssetMedia(context, maxAssets: 1), throwsStateError);
  });
}

class _Picker extends AssetPickerDelegate {
  _Picker(this.selection);

  final List<AssetEntity>? selection;
  AssetPickerConfig? config;

  @override
  Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    Key? key,
    AssetPickerConfig pickerConfig = const AssetPickerConfig(),
    PermissionRequestOption? permissionRequestOption,
    bool useRootNavigator = true,
    RouteSettings? pageRouteSettings,
    AssetPickerPageRouteBuilder<List<AssetEntity>>? pageRouteBuilder,
  }) async {
    config = pickerConfig;
    return selection;
  }
}

class _Asset extends Fake implements AssetEntity {
  _Asset(this.type, {this.fullSizeFile, this.originalFile});

  @override
  final AssetType type;
  final File? fullSizeFile;
  final File? originalFile;

  @override
  Future<File?> get file async => fullSizeFile;
  @override
  Future<File?> get originFile async => originalFile;
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
