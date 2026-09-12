import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';

void main() {
  const phoneSizes = [Size(320, 568), Size(430, 932)];

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
          home: Profile(repository: _StaticCurrentUserRepository()),
        ),
      );
      await tester.pumpAndSettle();

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
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Profile(repository: _StaticCurrentUserRepository()),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final gradientFinder =
        find.byKey(const ValueKey('profile-background-gradient'));
    final gradientContainer = tester.widget<Container>(gradientFinder);
    final gradient = (gradientContainer.decoration as BoxDecoration).gradient!
        as LinearGradient;

    expect(scaffold.backgroundColor, app_style.AppPalette.black);
    expect(tester.getSize(gradientFinder).height, closeTo(650, 0.01));
    expect(gradient.stops, const [0.0, 0.6]);
    expect(tester.takeException(), isNull);
  });
}

class _StaticCurrentUserRepository implements CurrentUserRepository {
  @override
  Future<CurrentUserProfile> load() async => _profile;
}

final _profile = CurrentUserProfile(
  userId: 1,
  username: 'planetowner',
  firstName: 'Planet',
  lastName: 'Owner',
  email: 'owner@example.com',
  avatarUri: null,
  favoriteTeamId: 83,
  createdAt: DateTime.utc(2026),
);
