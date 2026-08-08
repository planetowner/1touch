import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile.dart';
import 'package:onetouch/core/style.dart' as app_style;

void main() {
  const phoneSizes = [Size(320, 568), Size(393, 852)];

  for (final size in phoneSizes) {
    testWidgets('Profile light mode follows the design at ${size.height}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.whitetheme,
          home: const Profile(),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final gradientFinder =
          find.byKey(const ValueKey('profile-background-gradient'));
      final gradientContainer = tester.widget<Container>(gradientFinder);
      final gradient = (gradientContainer.decoration as BoxDecoration).gradient!
          as LinearGradient;
      final statCard = tester.widget<Container>(
        find.byKey(const ValueKey('profile-stat-card')),
      );

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -650),
      );
      await tester.pump();

      final playerList =
          find.byKey(const ValueKey('profile-following-player-list'));
      final jerseyBadgeFinder = find
          .descendant(of: playerList, matching: find.byType(CircleAvatar))
          .first;
      final jerseyBadge = tester.widget<CircleAvatar>(jerseyBadgeFinder);
      final jerseyNumber = tester.widget<Text>(
        find.descendant(
          of: jerseyBadgeFinder,
          matching: find.byType(Text),
        ),
      );
      final expectedGradientHeight =
          (size.height * 0.70).clamp(550.0, 650.0).toDouble();

      expect(scaffold.backgroundColor, app_style.AppPalette.lightGreyBox);
      expect(tester.getSize(gradientFinder).height, expectedGradientHeight);
      expect(gradient.colors.last, app_style.AppPalette.lightGreyBox);
      expect(gradient.stops, const [0.0, 0.9]);
      expect(
        (statCard.decoration as BoxDecoration).color,
        app_style.AppPalette.white,
      );
      expect(jerseyBadge.backgroundColor, app_style.AppPalette.white);
      expect(jerseyNumber.style?.color, app_style.AppPalette.black);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Profile dark mode uses the responsive background geometry',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: const Profile(),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final gradientFinder =
        find.byKey(const ValueKey('profile-background-gradient'));
    final gradientContainer = tester.widget<Container>(gradientFinder);
    final gradient = (gradientContainer.decoration as BoxDecoration).gradient!
        as LinearGradient;

    expect(scaffold.backgroundColor, app_style.AppPalette.black);
    expect(tester.getSize(gradientFinder).height, closeTo(596.4, 0.01));
    expect(gradient.stops, const [0.0, 0.6]);
    expect(tester.takeException(), isNull);
  });
}
