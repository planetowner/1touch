import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insta_assets_crop/insta_assets_crop.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/media/avatar_photo_library.dart';
import 'package:onetouch/features/media/avatar_picker_screen.dart';
import 'package:onetouch/features/media/native_avatar_header.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  const cropChannel = MethodChannel('plugins.legoffmael.dev/insta_assets_crop');
  late Directory directory;
  late _Library library;
  final cropCalls = <MethodCall>[];

  setUp(() {
    directory = Directory.systemTemp.createTempSync('avatar_gallery_');
    cropCalls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cropChannel, null);
    directory.deleteSync(recursive: true);
  });

  Future<void> prepare(WidgetTester tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, 180, 320), Paint()..color = Colors.blue);
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, 180, 100), Paint()..color = Colors.red);
      final picture = recorder.endRecording();
      final image = await picture.toImage(180, 320);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      picture.dispose();
      final file =
          await File('${directory.path}/portrait.png').writeAsBytes(bytes);
      library = _Library(file, bytes);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(cropChannel, (call) async {
      cropCalls.add(call);
      return call.method == 'sampleImage'
          ? library.source.path
          : '${directory.path}/cropped.jpg';
    });
  }

  Future<void> settlePhoto(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 50; i++) {
        await tester.pump();
        if (find.byType(NativeAvatarHeader).evaluate().isNotEmpty &&
            tester
                    .widget<NativeAvatarHeader>(find.byType(NativeAvatarHeader))
                    .onDone !=
                null) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester,
      {Brightness brightness = Brightness.light,
      Size size = const Size(390, 844),
      void Function(XFile?)? result}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: (brightness == Brightness.dark ? darktheme : whitetheme)
          .copyWith(platform: TargetPlatform.linux),
      home: Builder(
          builder: (context) => TextButton(
                onPressed: () async {
                  final file = await Navigator.of(context).push<XFile>(
                      MaterialPageRoute(
                          builder: (_) =>
                              AvatarPickerScreen(library: library)));
                  result?.call(file);
                },
                child: const Text('OPEN'),
              )),
    ));
    await tester.tap(find.text('OPEN'));
    await settlePhoto(tester);
  }

  CropState crop(WidgetTester tester) =>
      tester.state<CropState>(find.byType(Crop));
  NativeAvatarHeader header(WidgetTester tester) =>
      tester.widget<NativeAvatarHeader>(find.byType(NativeAvatarHeader));

  testWidgets('album outer edge follows native X inside the same safe area',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    final menu = find.byKey(const ValueKey('avatar-album-menu'));
    final cropState = crop(tester);
    expect(tester.getRect(menu).left, 16);
    addTearDown(tester.view.resetPadding);

    for (final safeLeft in [0.0, 24.0]) {
      tester.view.padding = FakeViewPadding(left: safeLeft);
      await tester.pump();
      for (final iconLeft in [18.333, 26.5, 20.25]) {
        header(tester).onCloseIconLeftMeasured!(iconLeft);
        await tester.pump();
        final headerLeft = tester.getRect(find.byType(NativeAvatarHeader)).left;
        expect(headerLeft, safeLeft);
        expect(tester.getRect(menu).left, closeTo(headerLeft + iconLeft, .001));
        expect(crop(tester), same(cropState));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'gallery collapses while header stays fixed; crop pan survives reopening',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    expect(header(tester).onDone, isNotNull);
    expect(find.byKey(const ValueKey('avatar-show-crop')), findsNothing);
    expect(
        find.byKey(const ValueKey('avatar-selected-overlay')), findsOneWidget);
    final original = crop(tester).area!;
    final state = crop(tester);
    final headerRect = tester.getRect(find.byType(NativeAvatarHeader));
    await tester.drag(find.byType(Crop), const Offset(0, -65));
    await tester.pumpAndSettle();
    final moved = crop(tester).area!;
    expect(moved.top, greaterThan(original.top));
    final scroll = tester
        .widget<NestedScrollView>(find.byType(NestedScrollView))
        .controller!;
    expect(scroll.offset, 0);

    await tester.dragFrom(const Offset(180, 760), const Offset(0, -580));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(300));
    expect(tester.getRect(find.byType(NativeAvatarHeader)), headerRect);
    await tester.dragFrom(const Offset(180, 450), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(crop(tester), same(state));
    expect(crop(tester).area, moved);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'album changes keep crop and recent photo selection opens the crop',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    final before = crop(tester);
    await tester.tap(find.byKey(const ValueKey('avatar-album-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    expect(library.pages.last.$1, 'travel');
    expect(crop(tester), same(before));
    expect(find.text('Travel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection shows the cached image before a larger preview loads',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    await tester.runAsync(() => precacheImage(MemoryImage(library.bytes),
        tester.element(find.byType(AvatarPickerScreen))));
    final preview = Completer<Uint8List?>();
    library.previews['photo-1'] = preview.future;
    final oldArea = crop(tester).area!;
    await tester.drag(find.byType(Crop), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(crop(tester).area, isNot(oldArea));

    await tester.tap(find.byKey(const ValueKey('photo-1')));
    await tester.pump();
    await tester.pump();
    expect(header(tester).onDone, isNotNull);
    expect(
        find.descendant(
            of: find.byType(Crop),
            matching: find.byType(CircularProgressIndicator)),
        findsNothing);
    final displayed = tester.widget<RawImage>(find.descendant(
        of: find.byType(Crop), matching: find.byType(RawImage)));
    expect(displayed.image, isNotNull);
    expect(crop(tester).area, oldArea);
    expect(library.fileRequests, isEmpty);

    await tester.drag(find.byType(Crop), const Offset(0, -45));
    await tester.pumpAndSettle();
    final state = crop(tester);
    final area = state.area;
    final upgradedBytes = Uint8List.fromList(library.bytes);
    preview.complete(upgradedBytes);
    await tester.runAsync(() => precacheImage(MemoryImage(upgradedBytes),
        tester.element(find.byType(AvatarPickerScreen))));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(
        find.descendant(of: find.byType(Crop), matching: find.byType(Image)));
    expect((image.image as MemoryImage).bytes, same(upgradedBytes));
    expect(crop(tester), same(state));
    expect(crop(tester).area, area);
    expect(library.fileRequests, isEmpty);
  });

  for (final fails in [false, true]) {
    testWidgets(
        'late preview ${fails ? 'error' : 'response'} cannot overwrite a newer selection',
        (tester) async {
      await prepare(tester);
      await mount(tester);
      final old = Completer<Uint8List?>();
      library.previews['photo-1'] = old.future;
      await tester.tap(find.byKey(const ValueKey('photo-1')));
      await tester.pump();
      expect(header(tester).onDone, isNotNull);
      await tester.tap(find.byKey(const ValueKey('photo-2')));
      await settlePhoto(tester);
      expect(header(tester).onDone, isNotNull);
      final current = crop(tester);
      if (fails) {
        old.completeError(const FileSystemException('Old request failed'));
      } else {
        old.complete(Uint8List.fromList(library.bytes));
      }
      await tester.pumpAndSettle();
      expect(header(tester).onDone, isNotNull);
      expect(crop(tester), same(current));
      final image = tester.widget<Image>(
          find.descendant(of: find.byType(Crop), matching: find.byType(Image)));
      expect((image.image as MemoryImage).bytes, same(library.bytes));
      expect(find.text('Unable to update profile photo. Please try again.'),
          findsNothing);
    });
  }

  testWidgets(
      'save exports the visible square once and returns it to profile upload',
      (tester) async {
    await prepare(tester);
    XFile? result;
    await mount(tester, result: (file) => result = file);
    await tester.drag(find.byType(Crop), const Offset(0, -60));
    await tester.pumpAndSettle();
    final area = crop(tester).area!;
    final save = header(tester).onDone!;
    save();
    save();
    await tester.pumpAndSettle();
    expect(cropCalls.map((call) => call.method), ['sampleImage', 'cropImage']);
    final args = cropCalls.last.arguments;
    expect(args['left'], closeTo(area.left, .0001));
    expect(args['top'], closeTo(area.top, .0001));
    expect(args['right'], closeTo(area.right, .0001));
    expect(result?.path, '${directory.path}/cropped.jpg');
    expect(result?.mimeType, 'image/jpeg');
    expect(library.fileRequests, ['photo-0']);
  });

  testWidgets(
      'confirmation waits for the selected full file and retains its crop',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    final fullFile = Completer<File?>();
    library.pending['photo-2'] = fullFile.future;
    await tester.tap(find.byKey(const ValueKey('photo-2')));
    await settlePhoto(tester);
    await tester.drag(find.byType(Crop), const Offset(0, -60));
    await tester.pumpAndSettle();
    final area = crop(tester).area!;
    expect(library.fileRequests, isEmpty);

    header(tester).onDone!();
    await tester.pump();
    expect(library.fileRequests, ['photo-2']);
    expect(header(tester).saving, isTrue);
    expect(cropCalls, isEmpty);
    expect(crop(tester).area, area);
    fullFile.complete(library.source);
    await tester.pumpAndSettle();
    expect(cropCalls.map((call) => call.method), ['sampleImage', 'cropImage']);
    expect(cropCalls.last.arguments['top'], closeTo(area.top, .0001));
  });

  testWidgets('full file failure leaves the selected crop available to retry',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    final fullFile = Completer<File?>();
    library.pending['photo-0'] = fullFile.future;
    final state = crop(tester);
    header(tester).onDone!();
    await tester.pump();
    fullFile.completeError(const FileSystemException('Photo unavailable'));
    await tester.pumpAndSettle();
    expect(header(tester).saving, isFalse);
    expect(header(tester).onDone, isNotNull);
    expect(crop(tester), same(state));
    expect(cropCalls, isEmpty);
    expect(find.text('Unable to update profile photo. Please try again.'),
        findsOneWidget);
  });

  testWidgets('cancel returns no file and does not export', (tester) async {
    await prepare(tester);
    var returned = false;
    await mount(tester, result: (file) {
      returned = true;
      expect(file, isNull);
    });
    header(tester).onCancel!();
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(cropCalls, isEmpty);
  });

  testWidgets('pinch zoom keeps the crop centered and survives collapsing',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    final before = crop(tester).area!;
    final center = tester.getCenter(find.byType(Crop));
    final first =
        await tester.startGesture(center - const Offset(35, 0), pointer: 1);
    final second =
        await tester.startGesture(center + const Offset(35, 0), pointer: 2);
    await tester.pump();
    await first.moveTo(center - const Offset(90, 0));
    await second.moveTo(center + const Offset(90, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    final zoomed = crop(tester).area!;
    expect(zoomed.width, lessThan(before.width));
    await tester.dragFrom(const Offset(180, 760), const Offset(0, -390));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-0')));
    await tester.pumpAndSettle();
    expect(crop(tester).area, zoomed);
    expect(
        tester
            .widget<NestedScrollView>(find.byType(NestedScrollView))
            .controller!
            .offset,
        0);
  });

  testWidgets(
      'camera cancellation retains the crop and a captured photo replaces it',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    final before = crop(tester);
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();
    expect(crop(tester), same(before));
    library.cameraPhoto = library.source;
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await settlePhoto(tester);
    expect(header(tester).onDone, isNotNull);
    expect(library.cameraCalls, 2);
  });

  testWidgets('the gallery reads another page as the user approaches its end',
      (tester) async {
    await prepare(tester);
    await mount(tester);
    await tester.flingFrom(
        const Offset(180, 760), const Offset(0, -1600), 6000);
    await tester.pumpAndSettle();
    expect(library.pages, contains(('recent', 1)));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'limited access can be changed; revocation clears the previous crop',
      (tester) async {
    await prepare(tester);
    library.permission = PermissionState.limited;
    await mount(tester);
    expect(find.text('Only selected photos are visible.'), findsOneWidget);
    expect(header(tester).onDone, isNotNull);
    library.permission = PermissionState.denied;
    await tester.tap(find.text('Manage photos'));
    await tester.pumpAndSettle();
    expect(library.managed, 1);
    expect(header(tester).onDone, isNull);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.byType(Crop), findsNothing);
  });

  testWidgets('permission denied does not query the library', (tester) async {
    await prepare(tester);
    library.permission = PermissionState.denied;
    await mount(tester);
    expect(library.pages, isEmpty);
    expect(find.text('Open settings'), findsOneWidget);
    expect(header(tester).onCancel, isNotNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'compact layout follows $brightness app colors without overflow',
        (tester) async {
      await prepare(tester);
      await mount(tester, size: const Size(320, 568), brightness: brightness);
      final context = tester.element(find.byType(AvatarPickerScreen));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.of(context).pageBackground);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Crop)).width, lessThanOrEqualTo(320));
    });
  }
}

class _Library extends AvatarPhotoLibrary {
  _Library(this.source, this.bytes);
  final File source;
  final Uint8List bytes;
  PermissionState permission = PermissionState.authorized;
  final pages = <(String, int)>[];
  final pending = <String, Future<File?>>{};
  final previews = <String, Future<Uint8List?>>{};
  final fileRequests = <String>[];
  int managed = 0;
  File? cameraPhoto;
  int cameraCalls = 0;
  @override
  Future<PermissionState> requestAccess() async => permission;
  @override
  Future<PermissionState> access() async => permission;
  @override
  Future<List<AssetPathEntity>> albums() async => [
        AssetPathEntity(id: 'recent', name: 'Recent', isAll: true),
        AssetPathEntity(id: 'travel', name: 'Travel'),
      ];
  @override
  Future<List<AssetEntity>> photos(AssetPathEntity album, int page) async {
    pages.add((album.id, page));
    return List.generate(
        page == 0 ? 80 : 12,
        (index) => AssetEntity(
              id: 'photo-${page * 80 + index}',
              typeInt: 1,
              width: 180,
              height: 320,
            ));
  }

  @override
  Future<Uint8List?> thumbnail(AssetEntity photo, {int size = 240}) =>
      (size == 1600 ? previews[photo.id] : null) ?? Future.value(bytes);
  @override
  Future<File?> file(AssetEntity photo) {
    fileRequests.add(photo.id);
    return pending[photo.id] ?? Future.value(source);
  }

  @override
  Future<void> manageAccess() async {
    managed++;
  }

  @override
  Future<File?> takePhoto() async {
    cameraCalls++;
    return cameraPhoto;
  }
}
