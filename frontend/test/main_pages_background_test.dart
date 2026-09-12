import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/CommunityScreen.dart';
import 'package:onetouch/screens/HomeScreen.dart';
import 'package:onetouch/screens/PlayerScreen.dart';
import 'package:onetouch/screens/TeamScreen.dart';

void main() {
  final pages = <({String name, Widget screen, String gradientKey})>[
    (
      name: 'home',
      screen: const HomeScreen(repository: _StaticHomeRepository()),
      gradientKey: 'home-brand-gradient',
    ),
    (
      name: 'players',
      screen: const Players(),
      gradientKey: 'players-brand-gradient',
    ),
    (
      name: 'team',
      screen: TeamScreen(teamId: 9),
      gradientKey: 'team-brand-gradient',
    ),
    (
      name: 'community',
      screen: const Community(teamId: 9),
      gradientKey: 'community-brand-gradient',
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
      expect(appBar.foregroundColor, app_style.AppPalette.white);
      expect(
        tester.getSize(find.byKey(ValueKey(page.gradientKey))).height,
        closeTo(596.4, 0.01),
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
    );
  }
}
