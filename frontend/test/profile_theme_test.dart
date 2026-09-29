import 'support/app_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      final statCard = tester.widget<Container>(
        find.byKey(const ValueKey('profile-stat-card')),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-stat-card')),
          matching: find.text('0'),
        ),
        findsNWidgets(3),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-stat-card')),
          matching: find.text('—'),
        ),
        findsNothing,
      );
      final statCardRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-card')),
      );
      final pointsRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-points')),
      );
      final postsRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-posts')),
      );
      final commentsRect = tester.getRect(
        find.byKey(const ValueKey('profile-stat-comments')),
      );
      final expectedStatWidth = (statCardRect.width - 48 - 4 - 20) / 3;
      expect(statCard.padding,
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16));
      expect(
        (statCard.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(8),
      );
      expect(pointsRect.left - statCardRect.left, 24);
      expect(pointsRect.width, closeTo(expectedStatWidth, 0.1));
      expect(postsRect.width, closeTo(expectedStatWidth, 0.1));
      expect(commentsRect.width, closeTo(expectedStatWidth, 0.1));
      expect(tester.getRect(find.text('COMMENTS')).right,
          lessThanOrEqualTo(commentsRect.right + 0.1));
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('COMMENTS'))
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 8),
            ),
        hasLength(1),
      );
      expect(postsRect.left, greaterThan(pointsRect.right));
      expect(commentsRect.left, greaterThan(postsRect.right));
      for (final dividerKey in ['points-posts', 'posts-comments']) {
        expect(
          tester.getSize(
            find.byKey(ValueKey('profile-stat-divider-$dividerKey')),
          ),
          const Size(2, 51),
        );
      }

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
      expect(scaffold.backgroundColor, app_style.AppPalette.lightGreyBox);
      expect(
        find.byKey(const ValueKey('profile-background-gradient')),
        findsNothing,
      );
      expect(
        (statCard.decoration as BoxDecoration).color,
        app_style.AppPalette.white,
      );
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
  firstName: 'Planet',
  lastName: 'Owner',
  email: 'owner@example.com',
  avatarUri: null,
  favoriteTeamId: 83,
  createdAt: DateTime.utc(2026),
);
