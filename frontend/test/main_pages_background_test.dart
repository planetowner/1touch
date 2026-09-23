import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/data/posts/mock/mock_post_repository.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/CommunityScreen.dart';
import 'support/stub_community_repository.dart';
import 'package:onetouch/screens/HomeScreen.dart';
import 'package:onetouch/screens/PlayerScreen.dart';

void main() {
  setUpAppCatalog();
  final pages = <({String name, Widget screen})>[
    (
      name: 'home',
      screen: HomeScreen(
          repository: const _StaticHomeRepository(),
          newsRepository: const _EmptyNewsRepository()),
    ),
    (
      name: 'players',
      screen: const Players(),
    ),
    (
      name: 'community',
      screen: Community(
        teamId: 9,
        postRepository: MockPostRepository(),
        communityRepository: const StubCommunityRepository(),
      ),
    ),
  ];

  for (final page in pages) {
    testWidgets('${page.name} uses light mode dark grey in light mode',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: app_style.whitetheme, home: page.screen),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final appBar =
          tester.widget<SliverAppBar>(find.byType(SliverAppBar).first);
      expect(scaffold.backgroundColor, app_style.AppPalette.lightModeDarkGrey);
      expect(
          appBar.foregroundColor,
          Theme.of(tester.element(find.byType(Scaffold).first))
              .colorScheme
              .onSurface);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient != null,
        ),
        findsNothing,
      );
    });
  }
}

class _StaticHomeRepository implements HomeRepository {
  const _StaticHomeRepository();

  @override
  Future<HomeData> load({DateTime? start, DateTime? end}) async {
    const favoriteTeam = Team(
      teamId: 8,
      name: 'Liverpool',
      shortCode: 'LIV',
      imagePath: 'https://cdn.example/8.png',
    );
    return HomeData(
      favoriteTeam: favoriteTeam,
      followingTeams: const [favoriteTeam],
      nextMatch: null,
      lastMatch: null,
      calendar: const [],
      highlights: const [],
    );
  }
}

// 배경 테스트는 뉴스 서버 설정이나 외부 피드에 의존하지 않아요.
class _EmptyNewsRepository implements NewsRepository {
  const _EmptyNewsRepository();

  @override
  Future<List<HomeContentItem>> loadForTeam(
    int teamId, {
    required String language,
  }) async =>
      const [];
}
