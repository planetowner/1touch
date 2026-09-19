import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/highlights/fixture_highlight_repository.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';
import 'package:onetouch/models/fixture_highlight.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('opens only the current fixture video at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _ControlledRepository();
      final launches = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        launches.add(call);
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(_screen(19722166, repository));
      expect(repository.ids, [19722166]);
      repository.requests[0].complete(_highlight(19722166, 'NLfa3K9ro5Y'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pump();
      expect(launches.single.arguments['url'],
          'https://www.youtube.com/watch?v=NLfa3K9ro5Y');
      expect(launches.single.arguments['useWebView'], false);

      await tester.pumpWidget(_screen(19872616, repository));
      expect(repository.ids, [19722166, 19872616]);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      repository.requests[1].complete(null);
      await tester.pump();
      expect(find.text('HIGHLIGHTS UNAVAILABLE'), findsOneWidget);
      await tester.tap(find.text('HIGHLIGHTS UNAVAILABLE'));
      expect(launches, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ignores a previous fixture response after navigating',
      (tester) async {
    final repository = _ControlledRepository();
    await tester.pumpWidget(_screen(1, repository));
    await tester.pumpWidget(_screen(2, repository));
    repository.requests[1].complete(null);
    await tester.pump();
    repository.requests[0].complete(_highlight(1, 'previous'));
    await tester.pump();
    expect(find.text('HIGHLIGHTS UNAVAILABLE'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed fixture lookup never shows another match',
      (tester) async {
    final repository = _ControlledRepository();
    await tester.pumpWidget(_screen(1, repository));
    repository.requests.single.completeError(StateError('offline'));
    await tester.pump();
    expect(find.text('HIGHLIGHTS UNAVAILABLE'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _screen(int fixtureId, FixtureHighlightRepository repository) =>
    MaterialApp(
      theme: app_style.whitetheme,
      home: Scaffold(
        body: MatchHighlights(fixtureId: fixtureId, repository: repository),
      ),
    );

FixtureHighlight _highlight(int fixtureId, String videoId) => FixtureHighlight(
      fixtureId: fixtureId,
      videoUrl: 'https://www.youtube.com/watch?v=$videoId',
      title: 'Official match highlights',
      thumbnailUrl: null,
    );

class _ControlledRepository implements FixtureHighlightRepository {
  final ids = <int>[];
  final requests = <Completer<FixtureHighlight?>>[];

  @override
  Future<FixtureHighlight?> loadForFixture(int fixtureId) {
    ids.add(fixtureId);
    final result = Completer<FixtureHighlight?>();
    requests.add(result);
    return result.future;
  }
}
