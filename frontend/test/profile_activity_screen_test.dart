import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/profile_activity_screen.dart';
import 'package:onetouch/core/app_segmented_toggle.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/models/current_user_profile.dart';

void main() {
  final profile = CurrentUserProfile(
    userId: 1,
    username: 'owner',
    firstName: 'John',
    lastName: 'Doe',
    email: 'john@example.com',
    avatarUri: null,
    favoriteTeamId: 83,
    createdAt: DateTime.utc(2026),
  );

  for (final theme in [darktheme, whitetheme]) {
    testWidgets('my activity switches between empty posts and comments',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: ProfileActivityScreen(profile: profile),
      ));
      await tester.pumpAndSettle();
      expect(find.text('John Doe'), findsOneWidget);
      expect(
          find.byType(AppSegmentedToggle<ProfileActivityTab>), findsOneWidget);
      final indicator = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('profile-activity-toggle-indicator')),
      );
      expect(
        (indicator.decoration as BoxDecoration).color,
        theme.brightness == Brightness.dark
            ? AppPalette.black
            : AppPalette.lightModeDarkGrey,
      );
      expect(find.byKey(const ValueKey('profile-activity-empty-posts')),
          findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('profile-activity-tab-comments')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-activity-empty-comments')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('profile-activity-empty-posts')),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
