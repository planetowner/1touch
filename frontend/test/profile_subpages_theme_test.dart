import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/About.dart';
import 'package:onetouch/comm_pages/Profile_settings/Contact.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/comm_pages/Profile_settings/Notification.dart';
import 'package:onetouch/comm_pages/Profile_settings/PlayerEdit.dart';
import 'package:onetouch/comm_pages/Profile_settings/Preference.dart';
import 'package:onetouch/comm_pages/Profile_settings/PreferenceDetails.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';

Color? _effectiveTextColor(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color;
}

void main() {
  final pages = <({String name, String title, Widget page})>[
    (
      name: 'personal info',
      title: 'LOGIN',
      page: const EditProfileScreen(),
    ),
    (
      name: 'notifications',
      title: 'Notifications',
      page: const NotificationListPage(),
    ),
    (
      name: 'team notifications',
      title: 'FC BARCELONA',
      page: const TeamNotificationDetailPage(teamName: 'FC Barcelona'),
    ),
    (
      name: 'player notifications',
      title: 'MOHAMED SALAH',
      page: const PlayerNotificationDetailPage(playerName: 'Mohamed Salah'),
    ),
    (
      name: 'preferences',
      title: 'Preferences',
      page: const PreferencePage(),
    ),
    (
      name: 'preference details',
      title: 'LANGUAGE',
      page: const PreferenceDetailScreen(
        title: 'Language',
        options: ['English', 'Korean'],
        selectedOption: 'English',
      ),
    ),
    (name: 'contact', title: 'Contact', page: const ContactPage()),
    (name: 'about', title: 'About', page: const AboutPage()),
  ];

  for (final testCase in pages) {
    testWidgets('${testCase.name} uses a normal light surface', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: app_style.whitetheme, home: testCase.page),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final titleFinder = find.text(testCase.title).first;

      expect(scaffold.backgroundColor, app_style.AppPalette.white);
      expect(
          _effectiveTextColor(tester, titleFinder), app_style.AppPalette.black);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('notification settings header uses body typography',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const NotificationListPage(),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text('Notifications')).style, Body1.style);
    expect(tester.takeException(), isNull);
  });

  for (final testCase in <({String title, Widget page})>[
    (title: 'About', page: const AboutPage()),
    (title: 'Contact', page: const ContactPage()),
  ]) {
    testWidgets('${testCase.title} header is centered with 24px icon gutters',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: app_style.whitetheme, home: testCase.page),
      );
      await tester.pump();

      expect(
          tester.getCenter(find.text(testCase.title)).dx, closeTo(196.5, 0.1));
      expect(tester.getCenter(find.byIcon(Icons.arrow_back_ios_new)).dx,
          closeTo(36, 0.1));
      expect(tester.getCenter(find.byIcon(Icons.search)).dx, closeTo(357, 0.1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('about rows and dividers use one 24px page gutter',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: app_style.whitetheme, home: const AboutPage()),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.text('Legal')).dx, closeTo(24, 0.1));
    expect(
      tester.getTopRight(find.byIcon(Icons.arrow_forward_ios).first).dx,
      closeTo(369, 0.1),
    );
    expect(tester.getTopLeft(find.byType(Divider).first).dx, closeTo(24, 0.1));
    expect(
        tester.getTopRight(find.byType(Divider).first).dx, closeTo(369, 0.1));
    expect(find.text('Visit Instagram'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final testCase in <({String name, ThemeData theme})>[
    (name: 'light', theme: app_style.whitetheme),
    (name: 'dark', theme: app_style.darktheme),
  ]) {
    testWidgets(
        'notification switches use the approved off state in ${testCase.name} mode',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: const TeamNotificationDetailPage(teamName: 'FC Barcelona'),
        ),
      );
      await tester.pump();

      final offSwitches = tester
          .widgetList<Switch>(find.byType(Switch))
          .where((toggle) => !toggle.value);
      expect(offSwitches, isNotEmpty);
      for (final toggle in offSwitches) {
        expect(toggle.inactiveThumbColor, app_style.AppPalette.white);
        expect(toggle.inactiveTrackColor, app_style.AppPalette.lightGrey);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final testCase in <({String name, Key key, Widget sheet})>[
    (
      name: 'following teams',
      key: const ValueKey('profile-team-edit-sheet'),
      sheet: const EditFollowingTeamsSheet(),
    ),
    (
      name: 'following players',
      key: const ValueKey('profile-player-edit-sheet'),
      sheet: const EditFollowingPlayersSheet(),
    ),
  ]) {
    for (final themeCase in <({
      String name,
      ThemeData theme,
      Color sheet,
      Color search,
    })>[
      (
        name: 'light',
        theme: app_style.whitetheme,
        sheet: app_style.AppPalette.white,
        search: app_style.AppPalette.lightGreyBox,
      ),
      (
        name: 'dark',
        theme: app_style.darktheme,
        sheet: app_style.AppPalette.darkGrey,
        search: app_style.AppPalette.lightGrey,
      ),
    ]) {
      testWidgets('${testCase.name} sheet uses ${themeCase.name} surfaces',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: themeCase.theme,
            home: Scaffold(body: testCase.sheet),
          ),
        );
        await tester.pump();

        final sheet = tester.widget<Container>(find.byKey(testCase.key));
        final searchKey = testCase.name == 'following teams'
            ? const ValueKey('profile-team-edit-search')
            : const ValueKey('profile-player-edit-search');
        final search = tester.widget<Container>(find.byKey(searchKey));
        expect((sheet.decoration as BoxDecoration).color, themeCase.sheet);
        expect((search.decoration as BoxDecoration).color, themeCase.search);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
