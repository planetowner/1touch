import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/home/home_content_repository.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/models/home_content.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/HomeScreen.dart';

void main() {
  testWidgets('loads Home and followed teams through the repository',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledHomeRepository();
    final contentRepository = _RecordingHomeContentRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          contentRepository: contentRepository,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.calls, hasLength(1));
    final now = DateTime.now();
    expect(repository.calls.single.start, DateTime(now.year, now.month, 1));
    expect(
      repository.calls.single.end,
      DateTime(now.year, now.month + 1, 0),
    );

    repository.calls.single.completer.complete(_homeData());
    await tester.pump();

    expect(contentRepository.requestedTeamIds, [1]);
    expect(find.text('Alpha FC'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(find.text('Following Teams'), findsOneWidget);
    expect(find.text('Beta FC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a retry state when the initial Home load fails',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          contentRepository: _RecordingHomeContentRepository(),
        ),
      ),
    );

    repository.calls.single.completer.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('Unable to load Home.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-retry-button')));
    await tester.pump();
    expect(repository.calls, hasLength(2));

    repository.calls.last.completer.complete(_homeData());
    await tester.pump();

    expect(find.text('Alpha FC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reloads calendar months and ignores a stale response',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          contentRepository: _RecordingHomeContentRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(repository.calls, hasLength(3));
    final now = DateTime.now();
    expect(
      repository.calls[1].start,
      DateTime(now.year, now.month + 1, 1),
    );
    expect(repository.calls[2].start, DateTime(now.year, now.month, 1));

    repository.calls[2].completer.complete(_homeData());
    await tester.pump();
    repository.calls[1].completer.complete(
      _homeData(favoriteTeam: const Team(teamId: 3, name: 'Late FC')),
    );
    await tester.pump();

    expect(find.text('Alpha FC'), findsOneWidget);
    expect(find.text('Late FC'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes previously displayed Home data when reloading fails',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledHomeRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(
          repository: repository,
          contentRepository: _RecordingHomeContentRepository(),
        ),
      ),
    );
    repository.calls.single.completer.complete(_homeData());
    await tester.pump();
    expect(find.text('Alpha FC'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    repository.calls.last.completer.completeError(StateError('invalid home'));
    await tester.pump();

    expect(find.text('Unable to load Home.'), findsOneWidget);
    expect(find.text('Alpha FC'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

HomeData _homeData({
  Team favoriteTeam = const Team(teamId: 1, name: 'Alpha FC'),
}) {
  return HomeData(
    favoriteTeam: favoriteTeam,
    followingTeams: [
      favoriteTeam,
      const Team(teamId: 2, name: 'Beta FC'),
    ],
    nextMatch: null,
    lastMatch: null,
    calendar: const [],
  );
}

class _HomeLoadCall {
  _HomeLoadCall({required this.start, required this.end});

  final DateTime? start;
  final DateTime? end;
  final Completer<HomeData> completer = Completer<HomeData>();
}

class _ControlledHomeRepository implements HomeRepository {
  final List<_HomeLoadCall> calls = [];

  @override
  Future<HomeData> load({DateTime? start, DateTime? end}) {
    final call = _HomeLoadCall(start: start, end: end);
    calls.add(call);
    return call.completer.future;
  }
}

class _RecordingHomeContentRepository implements HomeContentRepository {
  final List<int> requestedTeamIds = [];

  @override
  final HomeContent fallback = HomeContent(
    highlights: const [_fallbackContentItem],
    news: const [_fallbackContentItem],
  );

  @override
  Future<HomeContent> loadForTeam(int favoriteTeamId) async {
    requestedTeamIds.add(favoriteTeamId);
    return HomeContent(
      highlights: const [_loadedContentItem],
      news: const [_loadedContentItem],
    );
  }

  @override
  Future<HomeContentItem?> loadForMatch({
    required int homeTeamId,
    required int awayTeamId,
  }) async {
    return null;
  }
}

const _fallbackContentItem = HomeContentItem(
  title: 'Fallback content',
  source: 'Local',
  timeLabel: 'Latest',
);

const _loadedContentItem = HomeContentItem(
  title: 'Repository content',
  source: 'Repository',
  timeLabel: 'Now',
);
