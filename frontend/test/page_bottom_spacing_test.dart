import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/preference.dart';
import 'package:onetouch/core/bottom_navigation.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/features/community/community_access.dart';
import 'package:onetouch/features/community/post_detail_content.dart';

void main() {
  for (final size in [const Size(393, 852), const Size(402, 874)]) {
    for (final page in ['preferences', 'reply', 'read-only']) {
      testWidgets('$page bottom control is 48px above the tab bar at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final child = switch (page) {
          'preferences' => const PreferencePage(),
          'reply' => Scaffold(
              bottomNavigationBar: PostDetailReplyBar(
                replyTarget: null,
                onCancelReply: () {},
                onSubmit: (_) async {},
              ),
            ),
          _ => const Scaffold(bottomNavigationBar: CommunityReadOnlyNotice()),
        };
        await tester.pumpWidget(MaterialApp(
          theme: darktheme,
          home: Scaffold(
            body: child,
            bottomNavigationBar: OneTouchBottomNavigationBar(
              currentIndex: 3,
              onTap: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final content = switch (page) {
          'preferences' => find.byType(ElevatedButton),
          'reply' => find.byKey(const ValueKey('community-comment-input')),
          _ => find.byKey(const ValueKey('community-read-only-rule-notice')),
        };
        expect(
          tester.getTopLeft(find.byType(OneTouchBottomNavigationBar)).dy -
              tester.getBottomLeft(content).dy,
          closeTo(48, .1),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
