import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_section_tab_bar.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_delete_dialog.dart';
import 'package:onetouch/features/community/community_feed_widgets.dart';
import 'package:onetouch/features/notifications/unread_notification_bell_icon.dart';

void main() {
  testWidgets('three section tabs share the Figma 28px text gap',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = const Locale('en'));
    const labels = [
      ['전체', '자유', '분석', '뉴스·정보', '팬아트'],
      ['팀 정보', '일정', '순위', '스쿼드', '분석'],
      ['선수 정보', '분석', '경기', '커리어'],
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      for (var i = 0; i < labels.length; i++)
        DefaultTabController(
          length: labels[i].length,
          child: Builder(
              builder: (context) => SizedBox(
                    key: ValueKey('tabs-$i'),
                    child: appSectionTabBar(context,
                        controller: DefaultTabController.of(context),
                        labels: labels[i]),
                  )),
        ),
    ]))));
    for (var i = 0; i < labels.length; i++) {
      Finder label(int index) => find.descendant(
          of: find.byKey(ValueKey('tabs-$i')),
          matching: find.text(labels[i][index]));
      expect(tester.getTopLeft(label(0)).dx, 32);
      for (var j = 1; j < 3; j++) {
        expect(
            tester.getTopLeft(label(j)).dx -
                tester.getTopRight(label(j - 1)).dx,
            closeTo(28, .001));
      }
    }
    expect(tester.takeException(), isNull);
  });

  for (final right in [false, true]) {
    testWidgets(
        'author menu opens below its ${right ? 'right' : 'left'} trigger',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => Stack(children: [
                        Positioned(
                            top: 100,
                            left: right ? null : 24,
                            right: right ? 24 : null,
                            child: CommunityAuthorMenu(
                                boundaryContext: context,
                                onEdit: () {},
                                onDelete: () {})),
                      ])))));
      final trigger = tester.getRect(find.byType(CommunityAuthorMenu));
      await tester.tap(find.byType(CommunityAuthorMenu));
      await tester.pumpAndSettle();
      final surface = find
          .ancestor(of: find.text('Edit'), matching: find.byType(Material))
          .first;
      final menu = tester.getRect(surface);
      expect(menu.top, closeTo(trigger.bottom, .01));
      if (right) {
        expect(menu.right, closeTo(trigger.right, .01));
      } else {
        expect(menu.left, closeTo(trigger.left, .01));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final overflow in [-8.0, 0.0, 1.0]) {
    testWidgets('author menu flips only when content overflow is $overflow',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> openAt(double left, {double contentWidth = 345}) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: SizedBox(
                width: contentWidth,
                height: 600,
                child: Builder(
                    builder: (context) => Stack(children: [
                          Positioned(
                            top: 100,
                            left: left,
                            child: CommunityAuthorMenu(
                                boundaryContext: context,
                                onEdit: () {},
                                onDelete: () {}),
                          ),
                        ])),
              ),
            ),
          ),
        ));
        await tester.tap(find.byType(CommunityAuthorMenu));
        await tester.pumpAndSettle();
      }

      Rect menuRect() => tester.getRect(find
          .ancestor(of: find.text('Edit'), matching: find.byType(Material))
          .first);

      await openAt(0);
      final menuWidth = menuRect().width;
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await openAt(345 - menuWidth + overflow);
      final trigger = tester.getRect(find.byType(CommunityAuthorMenu));
      final menu = menuRect();
      expect(menu.top, closeTo(trigger.bottom, .01));
      if (overflow <= 0) {
        expect(menu.left, closeTo(trigger.left, .01));
      } else {
        expect(menu.right, closeTo(trigger.right, .01));
      }
      expect(menu.right, lessThanOrEqualTo(369));

      // 본문이 좁으면 화면에 여유가 있어도 본문 경계에서 정렬을 바꿔요.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await openAt(260 - menuWidth + overflow, contentWidth: 260);
      final narrowTrigger = tester.getRect(find.byType(CommunityAuthorMenu));
      final narrowMenu = menuRect();
      if (overflow <= 0) {
        expect(narrowMenu.left, closeTo(narrowTrigger.left, .01));
      } else {
        expect(narrowMenu.right, closeTo(narrowTrigger.right, .01));
      }
      expect(narrowMenu.right, lessThanOrEqualTo(284));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bell states, colors and divider match the original assets',
      (tester) async {
    tester.view.physicalSize = const Size(393, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    final boundary = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: darktheme,
        builder: (context, child) =>
            RepaintBoundary(key: boundary, child: child!),
        home: Scaffold(
            body: Column(children: [
          const SizedBox(height: 32),
          for (final background in [Colors.black, Colors.white])
            ColoredBox(
                color: background,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final unread in [false, true])
                        UnreadNotificationBellIcon(
                          color: background == Colors.black
                              ? Colors.white
                              : Colors.black,
                          hasUnread: unread,
                        ),
                    ],
                  ),
                )),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: CommunityPostSeparator()),
          const SizedBox(height: 16),
          Builder(
              builder: (context) => Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: CommunityAuthorMenu(
                        boundaryContext: context,
                        onEdit: () {},
                        onDelete: () {}),
                  ))),
        ]))));
    await tester.pumpAndSettle();
    final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
    final loaders =
        pictures.map((p) => p.bytesLoader).whereType<SvgAssetLoader>();
    expect(
        loaders.where((l) => l.assetName.endsWith('bell_default.svg')).length,
        2);
    expect(loaders.where((l) => l.assetName.endsWith('bell_unread.svg')).length,
        2);
    for (final bell in find.byType(UnreadNotificationBellIcon).evaluate()) {
      expect(tester.getSize(find.byWidget(bell.widget)), const Size(32, 32));
    }
    final lightUnread =
        loaders.where((l) => l.assetName.endsWith('bell_unread.svg')).last;
    expect(
        lightUnread.colorMapper!.substitute(null, 'path', 'fill', Colors.white),
        Colors.black);
    expect(
        lightUnread.colorMapper!
            .substitute(null, 'path', 'fill', const Color(0xFFFF5C5C)),
        const Color(0xFFFF5C5C));
    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.thickness, 2);
    expect(divider.color, const Color(0xFF3D3D3D));
    await tester.tap(find.byType(CommunityAuthorMenu));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    const output = String.fromEnvironment('COMMUNITY_CAPTURE_DIR');
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await render.toImage(pixelRatio: 3);
      final pixels =
          (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final line = tester.getRect(find.byType(Divider));
      var paintedRows = 0;
      // 3배 해상도에서도 디자인의 논리 두께 2가 실제 6픽셀인지 확인해요.
      for (var y = (line.top * 3).floor() - 3;
          y < (line.bottom * 3).ceil() + 3;
          y++) {
        final offset = (y * img.width + 100 * 3) * 4;
        if (pixels.getUint8(offset) == 61 &&
            pixels.getUint8(offset + 1) == 61 &&
            pixels.getUint8(offset + 2) == 61) {
          paintedRows++;
        }
      }
      expect(paintedRows, 6);
      if (output.isNotEmpty) {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/bell-states-and-divider.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      }
      img.dispose();
    });
  });
}
