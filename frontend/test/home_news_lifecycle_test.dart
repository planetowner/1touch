import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/HomeScreen.dart';
import 'package:onetouch/features/home/screen/home_screen_features.dart';

void main() {
  testWidgets('changing team removes old news and rejects its late response',
      (tester) async {
    final oldFavorite = currentUserPreferences.favoriteTeamId.value;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      currentUserPreferences.favoriteTeamId.value = oldFavorite;
    });
    final home = _HomeRepository();
    final content = _ContentRepository();
    await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(repository: home, newsRepository: content)));
    await tester.pump();
    expect(content.calls.single.teamId, 83);
    home.teamId = 3468;
    currentUserPreferences.favoriteTeamId.value = 3468;
    await tester.pump();
    await tester.pump();
    expect(content.calls.last.teamId, 3468);
    content.calls.last.completer.complete(_news('새 팀 기사'));
    await tester.pump();
    content.calls.first.completer.complete(_news('이전 팀 기사'));
    await tester.pump();
    await tester.scrollUntilVisible(find.byType(MyNews), 500,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('새 팀 기사'), findsOneWidget);
    expect(find.text('이전 팀 기사'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'returning to the retained Home tab refreshes news without a timer',
      (tester) async {
    final home = _HomeRepository();
    final content = _ContentRepository();
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          child: HomeScreen(repository: home, newsRepository: content),
          builder: (context, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
        )));
    await tester.pump();
    content.calls.single.completer.complete(_news('첫 기사'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 31));
    expect(content.calls, hasLength(1));
    active.value = false;
    await tester.pump();
    active.value = true;
    await tester.pump();
    await tester.pump();
    expect(content.calls, hasLength(2));
    content.calls.last.completer.complete(_news('새 기사'));
    await tester.pump();
    await tester.scrollUntilVisible(find.byType(MyNews), 500,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('새 기사'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

List<HomeContentItem> _news(String title) => [
      HomeContentItem(title: title, source: '공급자', timeLabel: '방금 전'),
    ];

class _HomeRepository implements HomeRepository {
  int teamId = 83;
  @override
  Future<HomeData> load({DateTime? start, DateTime? end}) async => HomeData(
        favoriteTeam: Team(teamId: teamId, name: '선택한 팀'),
        followingTeams: const [
          Team(teamId: 83, name: '바르셀로나'),
          Team(teamId: 3468, name: '레알 마드리드')
        ],
        nextMatch: null,
        lastMatch: null,
        calendar: const [],
        highlights: const [],
      );
}

class _ContentRepository implements NewsRepository {
  final calls = <({int teamId, Completer<List<HomeContentItem>> completer})>[];

  @override
  Future<List<HomeContentItem>> loadForTeam(
    int favoriteTeamId, {
    required String language,
  }) {
    final call =
        (teamId: favoriteTeamId, completer: Completer<List<HomeContentItem>>());
    calls.add(call);
    return call.completer.future;
  }
}
