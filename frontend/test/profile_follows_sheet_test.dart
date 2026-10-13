import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/profile_follows_sheet.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/profile/profile_follow_repository.dart';
import 'package:onetouch/models/profile_follow.dart';

void main() {
  for (final theme in [app_style.whitetheme, app_style.darktheme]) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      testWidgets('follow sheet uses ${theme.brightness} colors at $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _FollowRepository();
        var changes = 0;
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => ProfileFollowsSheet(
                          repository: repository,
                          initialTab: ProfileFollowTab.followers,
                          onChanged: () => changes++,
                        ),
                      ),
                      child: const Text('Open'),
                    )),
          ),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('profile-follows-sheet')),
            findsOneWidget);
        final sheet = tester.widget<Material>(
            find.byKey(const ValueKey('profile-follows-sheet')));
        expect(sheet.borderRadius,
            const BorderRadius.vertical(top: Radius.circular(24)));
        expect(
            tester
                .getSize(find.byKey(const ValueKey('profile-follows-sort')))
                .height,
            48);
        final track = tester.widget<Container>(
            find.byKey(const ValueKey('profile-follows-toggle')));
        final indicator = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('profile-follows-toggle-indicator')));
        final isLight = theme.brightness == Brightness.light;
        expect(
            (track.decoration as BoxDecoration).color,
            isLight
                ? app_style.AppPalette.lightModeDarkGrey
                : app_style.AppPalette.lightGrey);
        expect((indicator.decoration as BoxDecoration).color,
            isLight ? app_style.AppPalette.white : app_style.AppPalette.black);
        expect(tester.widget<Text>(find.text('FOLLOWERS')).style!.color,
            isLight ? app_style.AppPalette.black : app_style.AppPalette.white);
        expect(find.text('Follower'), findsOneWidget);
        expect(tester.widget<Text>(find.text('Follower')).style!.fontSize, 18);
        expect(find.byKey(const ValueKey('profile-follow-remove-2')),
            findsNothing);
        expect(repository.lastSort, ProfileFollowSort.newest);
        await tester.tap(find.byKey(const ValueKey('profile-follows-sort')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('profile-follows-sort-newest')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('profile-follows-sort-oldest')),
            findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey('profile-follows-sort-oldest')));
        await tester.pumpAndSettle();
        expect(repository.lastSort, ProfileFollowSort.oldest);
        expect(repository.lastOffset, 0);
        await tester
            .tap(find.byKey(const ValueKey('profile-follows-following-tab')));
        await tester.pumpAndSettle();
        expect(find.text('Following'), findsOneWidget);
        expect(repository.lastTab, ProfileFollowTab.following);
        expect(repository.lastSort, ProfileFollowSort.oldest);
        await tester.tap(find.byKey(const ValueKey('profile-follows-sort')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('profile-follows-sort-newest')));
        await tester.pumpAndSettle();
        expect(repository.lastSort, ProfileFollowSort.newest);
        await tester.tap(find.byKey(const ValueKey('profile-follow-remove-3')));
        await tester.pumpAndSettle();
        expect(changes, 1);
        expect(repository.following, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _FollowRepository implements ProfileFollowRepository {
  final followers = <ProfileFollowUser>[
    const ProfileFollowUser(userId: 2, name: 'Follower'),
  ];
  final following = <ProfileFollowUser>[
    const ProfileFollowUser(userId: 3, name: 'Following'),
  ];
  ProfileFollowTab? lastTab;
  ProfileFollowSort? lastSort;
  int? lastOffset;

  @override
  Future<ProfileFollowCounts> loadCounts() async => ProfileFollowCounts(
      followers: followers.length, following: following.length);

  @override
  Future<List<ProfileFollowUser>> loadUsers({
    required ProfileFollowTab tab,
    required ProfileFollowSort sort,
    int limit = 50,
    int offset = 0,
  }) async {
    lastTab = tab;
    lastSort = sort;
    lastOffset = offset;
    return (tab == ProfileFollowTab.followers ? followers : following)
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<void> unfollow(int userId) async {
    following.removeWhere((user) => user.userId == userId);
  }
}
