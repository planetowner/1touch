import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/favorite_team.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/community/mock/community_catalog.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/screens/CommunityScreen.dart';
import 'package:onetouch/screens/CommunityScreen_utils/AddPost.dart';
import 'package:onetouch/screens/CommunityScreen_utils/GroundRules.dart';
import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ReportDialog.dart';

Color? _effectiveTextColor(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color;
}

void _useCompactPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final testCase in <({
    String name,
    ThemeData theme,
    Color headerColor,
    Color tabColor,
  })>[
    (
      name: 'light',
      theme: app_style.whitetheme,
      headerColor: app_style.AppPalette.white,
      tabColor: app_style.AppPalette.black,
    ),
    (
      name: 'dark',
      theme: app_style.darktheme,
      headerColor: app_style.AppPalette.white,
      tabColor: app_style.AppPalette.white,
    ),
  ]) {
    testWidgets('Community main screen follows the ${testCase.name} design',
        (tester) async {
      _useCompactPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: const Community(teamId: 9),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final logo = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      final search = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('community-search-button')),
          matching: find.byType(Icon),
        ),
      );
      final profile = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('community-profile-button')),
          matching: find.byType(Icon),
        ),
      );
      final favorite = tester.widget<Icon>(
        find.byKey(const ValueKey('community-favorite-icon')),
      );
      final brandGradient =
          find.byKey(const ValueKey('community-brand-gradient'));
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));

      expect(
          scaffold.backgroundColor,
          app_style.mainPageBackground(
            tester.element(find.byType(Scaffold).first),
          ));
      expect(logo.colorFilter, isNotNull);
      expect(search.color, app_style.AppPalette.white);
      expect(profile.color, app_style.AppPalette.white);
      expect(
        _effectiveTextColor(
          tester,
          find.byKey(const ValueKey('community-team-name')),
        ),
        testCase.headerColor,
      );
      expect(favorite.color, testCase.headerColor);
      expect(tester.getSize(brandGradient).height, 550);
      expect(tabBar.labelColor, testCase.tabColor);
      expect(tabBar.indicatorColor, testCase.tabColor);
      expect(
        (tabBar.indicator! as UnderlineTabIndicator).borderSide.width,
        2,
      );
      expect(tabBar.padding, const EdgeInsets.only(left: 8));

      if (testCase.name == 'light') {
        final popular = tester.widget<Container>(
          find.byKey(const ValueKey('community-filter-popular')),
        );
        final groundRules = tester.widget<Container>(
          find.byKey(const ValueKey('community-ground-rules-card')),
        );
        expect(
          (popular.decoration as BoxDecoration).color,
          app_style.AppPalette.white,
        );
        expect(
          (groundRules.decoration as BoxDecoration).color,
          app_style.AppPalette.white,
        );
      } else {
        final popular = tester.widget<Container>(
          find.byKey(const ValueKey('community-filter-popular')),
        );
        final groundRules = tester.widget<Container>(
          find.byKey(const ValueKey('community-ground-rules-card')),
        );
        expect(
          (popular.decoration as BoxDecoration).color,
          app_style.AppPalette.lightGrey,
        );
        expect(
          (groundRules.decoration as BoxDecoration).color,
          app_style.AppPalette.lightGrey,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Community live badge follows repository fixture status',
      (tester) async {
    _useCompactPhone(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const Community(teamId: 9),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('community-live-badge')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const Community(teamId: 8),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('community-live-badge')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community dialogs use white light surfaces', (tester) async {
    _useCompactPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showGroundRulesModal(context),
                  child: const Text('Ground rules'),
                ),
                TextButton(
                  onPressed: () => showReportDialog(context),
                  child: const Text('Report post'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ground rules'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(
      find.byKey(const ValueKey('community-ground-rules-dialog')),
    );
    expect(dialog.backgroundColor, app_style.AppPalette.white);
    final firstNumberX = tester
        .getTopLeft(find.byKey(const ValueKey('ground-rule-number-1')))
        .dx;
    final fifthNumberX = tester
        .getTopLeft(find.byKey(const ValueKey('ground-rule-number-5')))
        .dx;
    final firstTitleX =
        tester.getTopLeft(find.byKey(const ValueKey('ground-rule-title-1'))).dx;
    final fifthTitleX =
        tester.getTopLeft(find.byKey(const ValueKey('ground-rule-title-5'))).dx;
    final firstSubtitleX = tester
        .getTopLeft(find.byKey(const ValueKey('ground-rule-subtitle-1')))
        .dx;
    expect(fifthNumberX, firstNumberX);
    expect(fifthTitleX, firstTitleX);
    expect(firstSubtitleX, firstTitleX);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('I UNDERSTAND!'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(bottomSheet.backgroundColor, app_style.AppPalette.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community dialogs use dark grey dark surfaces', (tester) async {
    _useCompactPhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showGroundRulesModal(context),
                  child: const Text('Ground rules'),
                ),
                TextButton(
                  onPressed: () => showReportDialog(context),
                  child: const Text('Report post'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ground rules'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<Dialog>(
      find.byKey(const ValueKey('community-ground-rules-dialog')),
    );
    expect(dialog.backgroundColor, app_style.AppPalette.darkGrey);
    await tester.tap(find.text('I UNDERSTAND!'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Report post'));
    await tester.pumpAndSettle();
    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(bottomSheet.backgroundColor, app_style.AppPalette.darkGrey);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community detail and composer use light surfaces',
      (tester) async {
    _useCompactPhone(tester);
    final originalFavoriteTeamId = FavoriteTeam.id.value;
    FavoriteTeam.id.value = 9;
    addTearDown(() => FavoriteTeam.id.value = originalFavoriteTeamId);
    final favoriteTeamColor = Color(mockTeamById(9).primaryColor);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: PostDetailScreen(post: mockPosts.first),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      app_style.AppPalette.lightModeDarkGrey,
    );
    final rulesCard = tester.widget<Container>(
      find.byKey(const ValueKey('community-detail-ground-rules-card')),
    );
    expect(
      (rulesCard.decoration as BoxDecoration).color,
      app_style.AppPalette.white,
    );
    final detailGradient = tester.widget<Container>(
      find.byKey(const ValueKey('community-detail-brand-gradient')),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('community-detail-brand-gradient')),
          )
          .height,
      550,
    );
    expect(
      ((detailGradient.decoration as BoxDecoration).gradient as LinearGradient)
          .colors
          .first,
      favoriteTeamColor,
    );
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const AddPost(),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      app_style.AppPalette.lightModeDarkGrey,
    );
    final category = tester.widget<Container>(
      find.byKey(const ValueKey('community-category-filter')),
    );
    final mediaPicker = tester.widget<Container>(
      find.byKey(const ValueKey('community-media-picker')),
    );
    expect(
      (category.decoration as BoxDecoration).color,
      app_style.AppPalette.white,
    );
    expect(
      (mediaPicker.decoration as BoxDecoration).color,
      const Color(0xFFC8C8C8),
    );
    final addGradient = tester.widget<Container>(
      find.byKey(const ValueKey('community-add-brand-gradient')),
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('community-add-brand-gradient')),
          )
          .height,
      550,
    );
    expect(
      ((addGradient.decoration as BoxDecoration).gradient as LinearGradient)
          .colors
          .first,
      favoriteTeamColor,
    );
    final generalFilterSize = tester.getSize(
      find.byKey(const ValueKey('community-category-filter')),
    );
    expect(generalFilterSize.height, 48);
    final categoryFilterTopLeft = tester.getTopLeft(
      find.byKey(const ValueKey('community-category-filter')),
    );
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(categoryFilterTopLeft.dy, greaterThanOrEqualTo(appBarBottom));
    await tester.tapAt(
      Offset(
        categoryFilterTopLeft.dx + generalFilterSize.width / 2,
        categoryFilterTopLeft.dy + 4,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ANALYSIS'), findsOneWidget);
    await tester.tap(find.text('ANALYSIS'));
    await tester.pumpAndSettle();
    expect(find.text('ANALYSIS'), findsOneWidget);
    final analysisFilterSize = tester.getSize(
      find.byKey(const ValueKey('community-category-filter')),
    );
    expect(analysisFilterSize.height, 48);
    expect(analysisFilterSize.width, greaterThan(generalFilterSize.width));
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
