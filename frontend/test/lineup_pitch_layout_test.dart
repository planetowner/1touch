import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/formation_layout.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/l10n/app_localizations.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final (width, height) in [
    (320.0, 700.0),
    (393.0, 940.0),
    (430.0, 1100.0)
  ]) {
    testWidgets(
        'keeps Korean formations inside the original pitch at ${width}x$height',
        (tester) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousLocale = appLocaleController.value;
      appLocaleController.value = const Locale('ko');
      addTearDown(() => appLocaleController.value = previousLocale);

      final away = _rows(2, '4-1-2-3', [
        'D. 리바코비치',
        'E. 가르시아',
        'P. 쿠바르시',
        'A. 크리스텐센',
        'J. 칸셀루',
        '로드리',
        'F. 로페스',
        '페드리',
        'L. 야말',
        '하피냐',
        'A. 고든',
      ]);
      final home = _rows(1, '4-2-3-1', [
        '골키퍼',
        'G. 수아소',
        '안드레스 카스트린',
        'A. 상간테',
        'J. 이글레시아스',
        'L. 아구메',
        'G. 코초라슈빌리',
        'F. 코헤이아',
        'Y. 포파나',
        'M. 앙헬 시에라',
        'R. 유어',
      ]).reversed.toList();
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: appLocalizationDelegates,
        supportedLocales: appSupportedLocales,
        theme: app_style.lightThemeForLocale(const Locale('ko')),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FootballNamesScope(
                names: const FootballNames(
                  players: {10002: '전체 이름'},
                  playerShortNames: {10002: 'A. 카스트린'},
                ),
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: LineupPitch(
                    awayRows: away,
                    homeRows: home,
                    awayColor: const Color(0xFF1E70BF),
                    homeColor: const Color(0xFFEF1935),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final pitch = tester.getRect(
        find.byKey(const ValueKey('match-lineup-card')),
      );
      expect(pitch.size, Size(width - 48, 820));
      final nameRects = <Rect>[];
      for (final player in [...away, ...home].expand((row) => row)) {
        final finder = find.byKey(ValueKey(
          'match-lineup-player-${player.teamId}-${player.playerId}',
        ));
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(pitch.left));
        expect(rect.right, lessThanOrEqualTo(pitch.right));
        expect(rect.top, greaterThanOrEqualTo(pitch.top));
        expect(rect.bottom, lessThanOrEqualTo(pitch.bottom));
        final expectedName = player.playerId == 10002 ? 'A. 카스트린' : player.name;
        final name =
            find.descendant(of: finder, matching: find.text(expectedName));
        expect(name, findsOneWidget);
        final nameText = tester.widget<Text>(name);
        expect(nameText.maxLines, 1);
        expect(nameText.overflow, TextOverflow.ellipsis);
        nameRects.add(tester.getRect(name));
      }
      for (var i = 0; i < nameRects.length; i++) {
        for (var j = i + 1; j < nameRects.length; j++) {
          expect(nameRects[i].overlaps(nameRects[j]), isFalse,
              reason: 'player names $i and $j');
        }
      }
      final scrollingNames = find.descendant(
        of: find.byKey(const ValueKey('match-lineup-card')),
        matching: find.byWidgetPredicate((widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal),
      );
      expect(scrollingNames, findsNothing);
      expect(tester.takeException(), isNull);

      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes =
            (await picture.toByteData(format: ui.ImageByteFormat.png))!
                .buffer
                .asUint8List();
        final file = File(
            'build/lineup-pitch-ko-${width.toInt()}x${height.toInt()}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        picture.dispose();
      });
    });
  }
}

List<List<LineupPlayer>> _rows(
    int teamId, String formation, List<String> names) {
  final layout = FormationLayout.forFormation(formation);
  final counts = [1, ...formation.split('-').map(int.parse)];
  var index = 0;
  return [
    for (var row = 1; row <= counts.length; row++)
      [
        for (var column = 1; column <= counts[row - 1]; column++)
          LineupPlayer(
            teamId: teamId,
            playerId: teamId * 10000 + index,
            number: index + 1,
            name: names[index++],
            formationPosition: layout.positionForSlot('$row:$column'),
            events: [
              if (row >= 4)
                const LineupEvent(type: LineupEventType.subOut, minute: 76),
              if (row == counts.length)
                const LineupEvent(type: LineupEventType.goal),
            ],
          ),
      ],
  ];
}
