import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/team_attributes/api/api_team_attribute_repository.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Analysis.dart';

void main() {
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
                team: const {'id': 83},
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
          (index) => chart.data.getTitle!(index, 0).text,
        ),
        teamAttributeLabels,
      );
      expect(
        chart.data.getTitle!(1, 0).positionPercentageOffset,
        0.3,
      );
      expect(
        chart.data.getTitle!(4, 0).positionPercentageOffset,
        0.3,
      );
      expect(
        chart.data.dataSets.every((dataSet) => dataSet.entryRadius == 0),
        isTrue,
      );
      expect(
        chart.data.dataSets.first.dataEntries.map((entry) => entry.value),
        [79.76, 73.57, 86.39, 72.96, 82.8],
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
      tester.getTopLeft(chevron).dx - tester.getTopRight(season).dx,
      lessThanOrEqualTo(8),
    );
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
    final filter = tester.widget<PopupMenuButton<int>>(
      find.byKey(const ValueKey('analysis-attributes-filter')),
    );
    expect(
      filter
          .itemBuilder(tester.element(filterFinder))
          .whereType<PopupMenuItem<int>>()
          .map((item) => item.value),
      [25659, 23621],
    );

    filter.onSelected!(23621);
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
      [79.76, 73.57, 86.39, 72.96, 82.8],
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
      tester.getTopLeft(selectedChevron).dx -
          tester.getTopRight(selectedSeason).dx,
      lessThanOrEqualTo(8),
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
          .dataEntries
          .first
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

    tester
        .widget<PopupMenuButton<int>>(
          find.byKey(const ValueKey('analysis-attributes-filter')),
        )
        .onSelected!(23621);
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
    final filter = tester.widget<PopupMenuButton<int>>(
      find.byKey(const ValueKey('analysis-attributes-filter')),
    );
    expect(
      filter
          .itemBuilder(
            tester.element(
              find.byKey(const ValueKey('analysis-attributes-filter')),
            ),
          )
          .whereType<PopupMenuItem<int>>()
          .map((item) => item.value),
      [23621],
    );
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

    final firstFilter = tester.widget<PopupMenuButton<int>>(
      find.byKey(const ValueKey('analysis-attributes-filter')),
    );
    firstFilter.onSelected!(25659);
    await tester.pump();
    final secondFilter = tester.widget<PopupMenuButton<int>>(
      find.byKey(const ValueKey('analysis-attributes-filter')),
    );
    secondFilter.onSelected!(23621);
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
          .dataEntries
          .first
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
    client: MockClient((request) {
      if (request.url.path.endsWith('/attributes/options')) {
        return optionsHandler?.call(request) ??
            Future.value(http.Response(jsonEncode(_optionsJson()), 200));
      }
      return handler(request);
    }),
    apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
    requestHeaders: const {},
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
  ApiTeamAttributeRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: app_style.whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AttributesSection(
            team: const {'id': 83},
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
  int seasonId = 27965,
  String seasonName = '2026/2027',
  bool isCurrent = true,
  double finishing = 79.76,
}) {
  return {
    'competition_id': 564,
    'season_id': seasonId,
    'season_name': seasonName,
    'is_current': isCurrent,
    'team_id': 83,
    'team_name': 'FC Barcelona',
    'model_id': 1,
    'possession_build_up': 82.8,
    'attacking_threat': 73.57,
    'chance_creation': 86.39,
    'finishing': finishing,
    'defending': 72.96,
    'attributes_updated_at': '2026-09-12T14:02:20Z',
  };
}
