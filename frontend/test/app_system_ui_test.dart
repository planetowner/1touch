import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_system_ui.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_attachment_viewer.dart';
import 'package:onetouch/features/media/avatar_picker_screen.dart';
import 'package:onetouch/features/media/avatar_photo_library.dart';
import 'package:onetouch/features/media/native_avatar_header.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:onetouch/rank_fav_teams.dart';

import 'support/app_fonts.dart';
import 'support/screen_pixels.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final theme in [whitetheme, darktheme]) {
    for (final inset in [24.0, 59.0]) {
      testWidgets(
          'surfaces and modal barriers reach the top: '
          '${theme.brightness}, inset $inset', (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: inset, bottom: 34);
        tester.view.viewPadding = FakeViewPadding(top: inset, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);

        const captureKey = ValueKey('surface-capture');
        late BuildContext pageContext;
        await tester.pumpWidget(RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: theme,
            builder: (_, child) => AppSystemUi(child: child!),
            home: Builder(builder: (context) {
              pageContext = context;
              return Scaffold(
                backgroundColor: mainPageBackground(context),
                body: const SafeArea(child: Text('Content')),
              );
            }),
          ),
        ));
        await tester.pumpAndSettle();

        final capture = find.byKey(captureKey);
        final points = [const Offset(8, 2), Offset(8, inset + 1)];
        final pageColor = mainPageBackground(pageContext);
        final suffix = '${theme.brightness.name}-${inset.toInt()}';
        Future<List<Color>> pixels(String name) =>
            screenPixels(tester, capture, points,
                screenshotName: '$name-$suffix');
        Brightness? statusIcons() => tester
            .renderObject<RenderRepaintBoundary>(capture)
            .debugLayer!
            .find<SystemUiOverlayStyle>(const Offset(196, 2))
            ?.statusBarIconBrightness;
        final normalIcons = theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light;
        expect(await pixels('page'), [pageColor, pageColor]);
        expect(statusIcons(), normalIcons);

        for (final sheet in [false, true]) {
          if (sheet) {
            showModalBottomSheet<void>(
                context: pageContext,
                builder: (_) =>
                    const SizedBox(width: double.infinity, height: 180));
          } else {
            showDialog<void>(
                context: pageContext,
                builder: (_) => const AlertDialog(content: Text('Dialog')));
          }
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byType(ModalBarrier).last).top, 0);
          final dimmed = await pixels(sheet ? 'sheet' : 'dialog');
          expect(dimmed.first, dimmed.last);
          expect(dimmed.first, isNot(pageColor));
          Navigator.of(pageContext).pop();
          await tester.pumpAndSettle();
          expect(await pixels('modal-return'), [pageColor, pageColor]);
        }

        showCommunityAttachmentViewer(pageContext,
            mediaUrl: 'https://example.invalid/photo.jpg');
        await tester.pumpAndSettle();
        final attachmentPixels = await pixels('attachment');
        expect(attachmentPixels.first, attachmentPixels.last);
        expect(attachmentPixels.first, isNot(pageColor));
        expect(statusIcons(), Brightness.light);
        expect(
            tester
                .getRect(
                    find.byKey(const ValueKey('community-attachment-close')))
                .top,
            greaterThanOrEqualTo(inset));
        Navigator.of(pageContext).pop();
        await tester.pumpAndSettle();
        expect(statusIcons(), normalIcons);

        Navigator.of(pageContext).push(MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: theme.copyWith(platform: TargetPlatform.linux),
            child: const AvatarPickerScreen(library: _DeniedPhotoLibrary()),
          ),
        ));
        await tester.pumpAndSettle();
        final avatarBackground = theme.extension<AppColors>()!.pageBackground;
        expect(await pixels('avatar-picker'),
            [avatarBackground, avatarBackground]);
        expect(statusIcons(), normalIcons);
        expect(tester.getRect(find.byType(NativeAvatarHeader)).top,
            greaterThanOrEqualTo(inset));
        Navigator.of(pageContext).pop();
        await tester.pumpAndSettle();
        expect(statusIcons(), normalIcons);

        Navigator.of(pageContext).push(MaterialPageRoute<void>(
          builder: (_) => const RankFavoriteTeamsScreen(selectedTeams: []),
        ));
        await tester.pumpAndSettle();
        final gradient = await pixels('gradient');
        expect(gradient.first, isNot(theme.scaffoldBackgroundColor));
        expect(statusIcons(), Brightness.light);
        expect(
            tester
                .getRect(
                    find.byKey(const ValueKey('rank-favorites-back-button')))
                .top,
            greaterThanOrEqualTo(inset));
        Navigator.of(pageContext).pop();
        await tester.pumpAndSettle();
        expect(await pixels('return'), [pageColor, pageColor]);
        expect(statusIcons(), normalIcons);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _DeniedPhotoLibrary extends AvatarPhotoLibrary {
  const _DeniedPhotoLibrary();
  @override
  Future<PermissionState> requestAccess() async => PermissionState.denied;
}
