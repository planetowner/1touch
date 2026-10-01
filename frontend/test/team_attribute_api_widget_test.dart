import 'support/app_catalog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/team_attributes/api/api_team_attribute_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Analysis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAppCatalog();
  setUpAll(() async {
    // 긴 축 이름의 줄바꿈을 앱에서 쓰는 글꼴의 폭으로 확인해요.
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf')))
        .load();
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
        'renders current API attributes at ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _repository(
        (_) async => http.Response(jsonEncode(_attributeJson()), 200),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.whitetheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttributesSection(
                team: const TeamOverview(
                  id: 83,
                  name: 'FC Barcelona',
                  shortName: 'BAR',
                  imagePath: '',
                ),
                repository: repository,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ATTRIBUTES'), findsOneWidget);
      final attributesCard = tester.widget<Container>(
        find.byKey(const ValueKey('analysis-attributes-card')),
      );
      expect(
        (attributesCard.decoration as BoxDecoration).boxShadow,
        app_style.lightModeCardShadows,
      );
      final chart = tester.widget<RadarChart>(find.byType(RadarChart));
      expect(
        List.generate(
          teamAttributeLabels.length,
          (index) => tester
              .widget<Text>(find.byKey(ValueKey('team-attribute-axis-$index')))
              .data!
              .replaceAll('\n', ' '),
        ),
        teamAttributeLabels,
      );
      final titleTextStyle = tester
          .widget<Text>(find.byKey(const ValueKey('team-attribute-axis-0')))
          .style!;
      expect(titleTextStyle.fontSize, 12);
      expect(titleTextStyle.fontFamily, 'Archivo');
      expect(titleTextStyle.fontWeight, FontWeight.w400);
      expect(titleTextStyle.height, 1.3);
      expect(
        chart.data.dataSets.every((dataSet) => dataSet.entryRadius == 0),
        isTrue,
      );
      expect(
        chart.data.dataSets.first.dataEntries.map((entry) => entry.value),
        [82.8, 73.57, 86.39, 79.76, 72.96],
      );
      expect(chart.data.dataSets.first.borderColor, const Color(0xFFD92455));
      expect(
        chart.data.dataSets.first.fillColor,
        const Color(0xFFD92455).withValues(alpha: 0.3),
      );
      expect(
        find.byKey(const ValueKey('analysis-attributes-filter')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final locale in appSupportedLocales) {
      testWidgets('balances radar labels in ${locale.languageCode} at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpAttributes(
          tester,
          _repository(
            (_) async => http.Response(jsonEncode(_attributeJson()), 200),
          ),
          locale: locale,
        );
        await tester.pumpAndSettle();

        final chartSize = tester.getSize(find.byType(RadarChart));
        expect(chartSize.width, closeTo(chartSize.height, 0.01));
        final card = tester.getRect(
          find.byKey(const ValueKey('analysis-attributes-card')),
        );
        expect(card.height, 300);
        expect(card.left, 24);
        expect(card.right, size.width - 24);
        final data = tester.widget<RadarChart>(find.byType(RadarChart)).data;
        final titles = [
          for (var index = 0; index < 5; index++)
            tester
                .widget<Text>(
                    find.byKey(ValueKey('team-attribute-axis-$index')))
                .data!,
        ];
        if (locale.languageCode == 'en') {
          expect(titles, [
            'Possession &\nBuild-Up',
            'Attacking\nThreat',
            'Chance\nCreation',
            'Shooting &\nFinishing',
            'Defending',
          ]);
        } else if (locale.languageCode == 'ko') {
          expect(titles, ['점유·빌드업', '공격 위협', '기회 창출', '슈팅·마무리', '수비력']);
        }
        expect(data.dataSets.first.dataEntries.map((entry) => entry.value),
            [82.8, 73.57, 86.39, 79.76, 72.96]);
        final center = tester.getCenter(find.byType(RadarChart));
        final outline = Path()
          ..addPolygon([
            for (var index = 0; index < 5; index++)
              center +
                  Offset(
                    chartSize.width *
                        0.4 *
                        math.cos(index * 2 * math.pi / 5 - math.pi / 2),
                    chartSize.height *
                        0.4 *
                        math.sin(index * 2 * math.pi / 5 - math.pi / 2),
                  ),
          ], true);
        final titleBounds = <Rect>[];
        for (var index = 0; index < 5; index++) {
          final finder = find.byKey(ValueKey('team-attribute-axis-$index'));
          final bounds = tester.getRect(finder);
          titleBounds.add(bounds);
          expect(bounds.left, greaterThanOrEqualTo(card.left));
          expect(bounds.right, lessThanOrEqualTo(card.right));
          expect(bounds.top, greaterThanOrEqualTo(card.top));
          expect(bounds.bottom, lessThanOrEqualTo(card.bottom));
          expect(
              Path.combine(
                      PathOperation.intersect, outline, Path()..addRect(bounds))
                  .getBounds()
                  .isEmpty,
              isTrue);
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          for (final box in paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: titles[index].length),
          )) {
            expect(box.left, greaterThanOrEqualTo(-0.5));
            expect(box.right, lessThanOrEqualTo(bounds.width + 0.5));
          }
        }
        // 위에서 시작해 오른쪽 위·아래, 왼쪽 아래·위로 이어져야 해요.
        expect(titleBounds[0].center.dx, closeTo(center.dx, 0.01));
        expect(titleBounds[0].bottom, lessThan(center.dy));
        for (final index in [1, 2]) {
          expect(titleBounds[index].center.dx, greaterThan(center.dx));
        }
        for (final index in [3, 4]) {
          expect(titleBounds[index].center.dx, lessThan(center.dx));
        }
        expect(titleBounds[1].bottom, lessThan(center.dy));
        expect(titleBounds[4].bottom, lessThan(center.dy));
        expect(titleBounds[2].top, greaterThan(center.dy));
        expect(titleBounds[3].top, greaterThan(center.dy));
        final topMargin = titleBounds[0].top - card.top;
        final bottomMargin = card.bottom -
            math.max(titleBounds[2].bottom, titleBounds[3].bottom);
        expect(topMargin, closeTo(bottomMargin, 1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('keeps the attributes title and filter inline at 393px',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpAttributes(
      tester,
      _repository(
        (_) async => http.Response(jsonEncode(_attributeJson()), 200),
      ),
    );

    final titleCenter = tester.getCenter(find.text('ATTRIBUTES'));
    expect(
      tester.getSize(
        find.byKey(const ValueKey('analysis-attributes-card')),
      ),
      const Size(345, 300),
    );
    final filterCenter = tester.getCenter(
      find.byKey(const ValueKey('analysis-attributes-filter')),
    );
    expect((titleCenter.dy - filterCenter.dy).abs(), lessThan(2));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('analysis-attributes-filter')))
          .width,
      lessThan(160),
    );
    final filterRight = tester.getTopRight(
      find.byKey(const ValueKey('analysis-attributes-filter')),
    );
    expect(filterRight.dx, closeTo(369, 1));
    final filter = find.byKey(const ValueKey('analysis-attributes-filter'));
    final season = find.descendant(of: filter, matching: find.text('SEASON'));
    final chevron = find.descendant(
      of: filter,
      matching: find.byIcon(Icons.keyboard_arrow_down),
    );
    expect(
      (tester.getCenter(season).dy - tester.getCenter(chevron).dy).abs(),
      lessThan(1),
    );
    expect(
      tester.getRect(filter).right - tester.getRect(chevron).right,
      closeTo(8, 0.1),
    );
    expect(tester.renderObject<RenderParagraph>(season).didExceedMaxLines,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads a selected historical comparison without hiding current',
      (tester) async {
    final historicalResponse = Completer<http.Response>();
    final repository = _repository((request) {
      if (request.url.queryParameters['season_id'] == '27965') {
        return Future.value(http.Response(jsonEncode(_attributeJson()), 200));
      }
      expectSync(request.url.queryParameters, {'season_id': '23621'});
      return historicalResponse.future;
    });
    await _pumpAttributes(tester, repository);

    final filterFinder = find.byKey(
      const ValueKey('analysis-attributes-filter'),
    );
    await _chooseAttributes(tester, 23621);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('analysis-attributes-comparison-loading')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<RadarChart>(find.byType(RadarChart))
          .data
          .dataSets
          .first
          .dataEntries
          .map((entry) => entry.value),
      [82.8, 73.57, 86.39, 79.76, 72.96],
    );

    historicalResponse.complete(
      http.Response(
        jsonEncode(
          _attributeJson(
            seasonId: 23621,
            seasonName: '2024/2025',
            isCurrent: false,
            finishing: 61,
          ),
        ),
        200,
      ),
    );
    await tester.pump();

    expect(
      find.descendant(of: filterFinder, matching: find.text('24/25')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: filterFinder, matching: find.byType(Image)),
      findsNothing,
    );
    final selectedSeason = find.descendant(
      of: filterFinder,
      matching: find.text('24/25'),
    );
    final selectedChevron = find.descendant(
      of: filterFinder,
      matching: find.byIcon(Icons.keyboard_arrow_down),
    );
    expect(
      (tester.getCenter(selectedSeason).dy -
              tester.getCenter(selectedChevron).dy)
          .abs(),
      lessThan(1),
    );
    expect(
      tester.getRect(filterFinder).right -
          tester.getRect(selectedChevron).right,
      closeTo(8, 0.1),
    );
    expect(find.text('24/25 FC BARCELONA'), findsOneWidget);
    final legendFinder = find.byKey(
      const ValueKey('analysis-attributes-legend'),
    );
    expect(tester.widget<SizedBox>(legendFinder).width, double.infinity);
    expect(
      tester
          .widget<Wrap>(
            find.descendant(of: legendFinder, matching: find.byType(Wrap)),
          )
          .alignment,
      WrapAlignment.end,
    );
    expect(
      tester
          .widget<RadarChart>(find.byType(RadarChart))
          .data
          .dataSets[1]
          .dataEntries[3]
          .value,
      61,
    );
    expect(
      tester
          .widget<RadarChart>(find.byType(RadarChart))
          .data
          .dataSets[1]
          .borderColor,
      const Color(0xFF1B6EBD).withValues(alpha: 0.85),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps current attributes visible when comparison fails',
      (tester) async {
    final repository = _repository((request) async {
      if (request.url.queryParameters['season_id'] == '27965') {
        return http.Response(jsonEncode(_attributeJson()), 200);
      }
      return http.Response('Not found', 404);
    });
    await _pumpAttributes(tester, repository);

    await _chooseAttributes(tester, 23621);
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('analysis-attributes-comparison-error')),
      findsOneWidget,
    );
    expect(
      tester.widget<RadarChart>(find.byType(RadarChart)).data.dataSets,
      hasLength(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('attribute filter requests the selected comparison team',
      (tester) async {
    final requestedTeams = <String>[];
    final repository = _repository((request) async {
      if (request.url.queryParameters['season_id'] == '27965') {
        return http.Response(jsonEncode(_attributeJson()), 200);
      }
      requestedTeams.add(request.url.path);
      return http.Response(
        jsonEncode(_attributeJson(
          teamId: 19,
          seasonId: 23614,
          seasonName: '2024/2025',
          isCurrent: false,
          competitionId: 8,
        )),
        200,
      );
    });
    await _pumpAttributes(tester, repository);
    await tester.tap(find.byKey(const ValueKey('analysis-attributes-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analysis-filter-season')));
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey('analysis-filter-season-2024/2025')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('analysis-filter-team-search')), 'Leeds');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('analysis-attributes-option-71-23614')),
      findsNothing,
    );
    await tester.enterText(
        find.byKey(const ValueKey('analysis-filter-team-search')), 'Arsenal');
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey('analysis-attributes-option-19-23614')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('analysis-filter-update')));
    await tester.pumpAndSettle();

    expect(requestedTeams, contains(contains('/teams/19/attributes')));
    expect(find.text('24/25 ARSENAL'), findsOneWidget);
  });

  testWidgets('keeps current attributes visible when options fail',
      (tester) async {
    final repository = _repository(
      (_) async => http.Response(jsonEncode(_attributeJson()), 200),
      optionsHandler: (_) async => http.Response('Unavailable', 503),
    );

    await _pumpAttributes(tester, repository);

    expect(find.byType(RadarChart), findsOneWidget);
    expect(
      find.byKey(const ValueKey('analysis-attributes-filter')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the newest stored season when none is current',
      (tester) async {
    final repository = _repository(
      (request) async {
        expect(request.url.queryParameters, {'season_id': '25659'});
        return http.Response(
          jsonEncode(
            _attributeJson(
              seasonId: 25659,
              seasonName: '2025/2026',
              isCurrent: false,
            ),
          ),
          200,
        );
      },
      optionsHandler: (_) async => http.Response(
        jsonEncode({
          'team_id': 83,
          'items': [
            {
              'competition_id': 564,
              'season_id': 25659,
              'season_name': '2025/2026',
              'is_current': false,
            },
            {
              'competition_id': 564,
              'season_id': 23621,
              'season_name': '2024/2025',
              'is_current': false,
            },
          ],
        }),
        200,
      ),
    );

    await _pumpAttributes(tester, repository);

    expect(find.byType(RadarChart), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analysis-attributes-filter')));
    await tester.pumpAndSettle();
    expect(find.text('24/25'), findsOneWidget);
  });

  testWidgets('does not invent a Barcelona request without a selected team',
      (tester) async {
    var requests = 0;
    final repository = _repository((_) async {
      requests += 1;
      return http.Response(jsonEncode(_attributeJson()), 200);
    }, optionsHandler: (_) async {
      requests += 1;
      return http.Response(jsonEncode(_optionsJson()), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: AttributesSection(team: null, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.text('No attribute data available'), findsOneWidget);
  });

  testWidgets('ignores stale historical comparison responses', (tester) async {
    final responses = <int, Completer<http.Response>>{};
    final repository = _repository((request) {
      final seasonId =
          int.tryParse(request.url.queryParameters['season_id'] ?? '');
      if (seasonId == 27965) {
        return Future.value(http.Response(jsonEncode(_attributeJson()), 200));
      }
      if (seasonId == null) {
        throw StateError('Expected an explicit attribute season.');
      }
      return responses.putIfAbsent(seasonId, Completer.new).future;
    });
    await _pumpAttributes(tester, repository);

    await _chooseAttributes(tester, 25659);
    await tester.pump();
    await _chooseAttributes(tester, 23621);
    await tester.pump();

    responses[23621]!.complete(
      http.Response(
        jsonEncode(
          _attributeJson(
            seasonId: 23621,
            seasonName: '2024/2025',
            isCurrent: false,
            finishing: 61,
          ),
        ),
        200,
      ),
    );
    await tester.pump();
    responses[25659]!.complete(
      http.Response(
        jsonEncode(
          _attributeJson(
            seasonId: 25659,
            seasonName: '2025/2026',
            isCurrent: false,
            finishing: 25,
          ),
        ),
        200,
      ),
    );
    await tester.pump();

    expect(find.text('24/25 FC BARCELONA'), findsOneWidget);
    expect(
      tester
          .widget<RadarChart>(find.byType(RadarChart))
          .data
          .dataSets[1]
          .dataEntries[3]
          .value,
      61,
    );
    expect(tester.takeException(), isNull);
  });
}

ApiTeamAttributeRepository _repository(
  Future<http.Response> Function(http.Request request) handler, {
  Future<http.Response> Function(http.Request request)? optionsHandler,
}) {
  return ApiTeamAttributeRepository(
    api: ApiClient(
        client: MockClient((request) {
          if (request.url.path.endsWith('/attributes/options')) {
            return optionsHandler?.call(request) ??
                Future.value(http.Response(jsonEncode(_optionsJson()), 200));
          }
          return handler(request);
        }),
        baseUri: Uri.parse('https://api.1touch.football/v1'),
        requestHeaders: () => const {}),
  );
}

Map<String, dynamic> _optionsJson() {
  return {
    'team_id': 83,
    'items': [
      {
        'competition_id': 564,
        'season_id': 27965,
        'season_name': '2026/2027',
        'is_current': true,
      },
      {
        'competition_id': 564,
        'season_id': 25659,
        'season_name': '2025/2026',
        'is_current': false,
      },
      {
        'competition_id': 564,
        'season_id': 23621,
        'season_name': '2024/2025',
        'is_current': false,
      },
    ],
  };
}

Future<void> _pumpAttributes(
  WidgetTester tester,
  ApiTeamAttributeRepository repository, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      theme: app_style.lightThemeForLocale(locale),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AttributesSection(
            team: const TeamOverview(
              id: 83,
              name: 'FC Barcelona',
              shortName: 'BAR',
              imagePath: '',
            ),
            repository: repository,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Map<String, dynamic> _attributeJson({
  int teamId = 83,
  int seasonId = 27965,
  int competitionId = 564,
  String seasonName = '2026/2027',
  bool isCurrent = true,
  double finishing = 79.76,
}) {
  return {
    'competition_id': competitionId,
    'season_id': seasonId,
    'season_name': seasonName,
    'is_current': isCurrent,
    'team_id': teamId,
    'team_name': teamId == 83 ? 'FC Barcelona' : 'Arsenal',
    'model_id': 1,
    'possession_build_up': 82.8,
    'attacking_threat': 73.57,
    'chance_creation': 86.39,
    'finishing': finishing,
    'defending': 72.96,
    'attributes_updated_at': '2026-09-12T14:02:20Z',
  };
}

Future<void> _chooseAttributes(WidgetTester tester, int seasonId) async {
  await tester.tap(find.byKey(const ValueKey('analysis-attributes-filter')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(find.byKey(const ValueKey('analysis-filter-season')));
  await tester.pump();
  final seasonName = switch (seasonId) {
    23621 => '2024/2025',
    25659 => '2025/2026',
    _ => throw ArgumentError.value(seasonId, 'seasonId'),
  };
  await tester.tap(find.byKey(ValueKey('analysis-filter-season-$seasonName')));
  await tester.pump();
  await tester.enterText(
    find.byKey(const ValueKey('analysis-filter-team-search')),
    'Barcelona',
  );
  await tester.pump();
  await tester
      .tap(find.byKey(ValueKey('analysis-attributes-option-83-$seasonId')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('analysis-filter-update')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
