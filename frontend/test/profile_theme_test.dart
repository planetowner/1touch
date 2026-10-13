import 'support/stub_profile_activity_repository.dart';
import 'support/stub_profile_follow_repository.dart';
import 'support/app_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/features/player/player_following_controller.dart';

void main() {
  setUpAppCatalog();
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
          home: Profile(
            loadPointBalance: () async => 1430,
            activityRepository: const StubProfileActivityRepository(),
            followRepository: const StubProfileFollowRepository(),
            followingController: PlayerFollowingController()
              ..loaded = true
              ..players = [
                const FollowingPlayer(
                    playerId: 123, name: 'API Player', imagePath: null)
              ],
            repository: _StaticCurrentUserRepository(),
            followingTeamsRepository: _StaticFollowingTeamsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('profile-back-button')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-notification-badge')),
          findsNothing);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final statCard = find.byKey(const ValueKey('profile-stat-card'));
      expect(
        find.descendant(
          of: statCard,
          matching: find.text('0'),
        ),
        findsNWidgets(2),
      );
      expect(find.text('200'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(tester.widget<Text>(find.text('200')).style?.fontSize, 24);
      expect(tester.widget<Text>(find.text('1430')).style?.fontSize, 32);
      expect(
          tester.getRect(find.text('pts')).left -
              tester.getRect(find.text('1430')).right,
          closeTo(4, 0.1));
      expect(
        tester
            .widget<Opacity>(find
                .ancestor(
                  of: find.text('pts'),
                  matching: find.byType(Opacity),
                )
                .first)
            .opacity,
        0.5,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-stat-followers')),
          matching: find.byIcon(Icons.how_to_reg_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-stat-following')),
          matching: find.byIcon(Icons.record_voice_over),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-stat-posts')),
          matching: find.byIcon(Icons.sticky_note_2),
        ),
        findsOneWidget,
      );
      final statCardRect = tester.getRect(statCard);
      final pointsRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-points')),
      );
      final followersRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-followers')),
      );
      final followingRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-following')),
      );
      final postsRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-posts')),
      );
      final commentsRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-comments')),
      );
      final expectedStatWidth = (statCardRect.width - 16) / 2;
      expect(pointsRect.bottom, lessThan(statCardRect.top));
      expect(followersRect.width, closeTo(expectedStatWidth, 0.1));
      expect(followingRect.width, closeTo(expectedStatWidth, 0.1));
      expect(postsRect.width, closeTo(expectedStatWidth, 0.1));
      expect(commentsRect.width, closeTo(expectedStatWidth, 0.1));
      expect(tester.getRect(find.text('COMMENTS')).right,
          lessThanOrEqualTo(commentsRect.right + 0.1));
      expect(followingRect.left, greaterThan(followersRect.right));
      expect(commentsRect.left, greaterThan(postsRect.right));
      expect(postsRect.top, greaterThan(followersRect.bottom));
      final statBackground = (tester
              .widget<Container>(find
                  .descendant(
                    of: find.byKey(const ValueKey('profile-stat-followers')),
                    matching: find.byType(Container),
                  )
                  .first)
              .decoration as BoxDecoration)
          .color;

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -650),
      );
      await tester.pump();

      final playerList =
          find.byKey(const ValueKey('players-favorites-section'));
      final playerLinks = find.descendant(
        of: playerList,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is InkWell &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>)
                  .value
                  .startsWith('favorite-player-'),
        ),
      );
      expect(playerLinks, findsWidgets);
      expect(
          tester
              .widgetList<InkWell>(playerLinks)
              .every((link) => link.onTap != null),
          isTrue);
      expect(scaffold.backgroundColor, app_style.AppPalette.lightModeDarkGrey);
      expect(
        find.byKey(const ValueKey('profile-background-gradient')),
        findsNothing,
      );
      expect(statBackground, app_style.AppPalette.white);
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
        home: Profile(
          loadPointBalance: () async => 1430,
          activityRepository: const StubProfileActivityRepository(),
          followRepository: const StubProfileFollowRepository(),
          followingController: PlayerFollowingController()
            ..loaded = true
            ..players = [
              const FollowingPlayer(
                  playerId: 123, name: 'API Player', imagePath: null)
            ],
          repository: _StaticCurrentUserRepository(),
          followingTeamsRepository: _StaticFollowingTeamsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, app_style.AppPalette.black);
    expect(
      (tester
              .widget<Container>(find
                  .descendant(
                    of: find.byKey(const ValueKey('profile-stat-posts')),
                    matching: find.byType(Container),
                  )
                  .first)
              .decoration as BoxDecoration)
          .color,
      const Color(0xFF272828),
    );
    expect(
      find.byKey(const ValueKey('profile-background-gradient')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

class _StaticCurrentUserRepository implements CurrentUserRepository {
  @override
  Future<CurrentUserProfile> load() async => _profile;
}

class _StaticFollowingTeamsRepository implements FollowingTeamsRepository {
  final ValueNotifier<List<Team>> _cache = ValueNotifier(const []);

  @override
  ValueListenable<List<Team>> get cachedTeams => _cache;

  @override
  Future<List<Team>> load() async {
    const teams = [Team(teamId: 83, name: 'FC Barcelona')];
    _cache.value = teams;
    return teams;
  }

  @override
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  }) =>
      throw UnimplementedError();
}

final _profile = CurrentUserProfile(
  userId: 1,
  username: 'planetowner',
  displayName: 'Planet Owner',
  email: 'owner@example.com',
  avatarUri: null,
  favoriteTeamId: 83,
  createdAt: DateTime.utc(2026),
);
