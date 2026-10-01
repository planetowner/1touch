import 'support/app_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/about.dart';
import 'package:onetouch/comm_pages/Profile_settings/contact.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/comm_pages/Profile_settings/notification.dart';
import 'package:onetouch/features/player/player_directory_sheets.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/comm_pages/Profile_settings/preference.dart';
import 'package:onetouch/comm_pages/Profile_settings/preference_details.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'support/player_detail_fixture.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/data/notifications/notification_preferences.dart';
import 'package:onetouch/data/notifications/notification_preferences_repository.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/player_detail.dart';

Color? _effectiveTextColor(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color;
}

void main() {
  setUpAppCatalog();
  final pages = <({String name, String title, Widget page})>[
    (
      name: 'personal info',
      title: 'LOGIN',
      page: const EditProfileScreen(),
    ),
    (
      name: 'notifications',
      title: 'Notifications',
      page: NotificationListPage(
        repository: _StaticNotificationPreferencesRepository(),
      ),
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
        home: NotificationListPage(
          repository: _StaticNotificationPreferencesRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text('Notifications')).style, Body1.style);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications hides following players when none are followed',
      (tester) async {
    final previousPlayers = playerFollowingController.players;
    playerFollowingController.players = [];
    addTearDown(() => playerFollowingController.players = previousPlayers);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: NotificationListPage(
          repository: _StaticNotificationPreferencesRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FOLLOWING PLAYERS'), findsNothing);
    expect(find.text('POSTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile real name cannot be edited after registration',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: const EditProfileScreen(),
      ),
    );

    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('profile-real-name-field')),
    );
    expect(nameField.readOnly, isTrue);
    expect(nameField.enableInteractiveSelection, isFalse);
    expect(nameField.showCursor, isFalse);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
  });

  testWidgets('personal info values have an 8px gap before right actions',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: const EditProfileScreen(),
      ),
    );
    await tester.pump();

    final usernameField = find.byKey(
      const ValueKey('profile-username-field'),
    );
    final firstClearAction = find
        .ancestor(
          of: find.byIcon(Icons.close).first,
          matching: find.byType(SizedBox),
        )
        .first;
    final fieldRect = tester.getRect(usernameField);
    final actionRect = tester.getRect(firstClearAction);

    expect(actionRect.left - fieldRect.right, 8);
    expect(actionRect.right, 369);
    final actionCenters = <double>[
      for (final icon in [
        ...find.byIcon(Icons.lock_outline).evaluate(),
        ...find.byIcon(Icons.close).evaluate(),
      ])
        tester
            .getCenter(find.byElementPredicate((element) => element == icon))
            .dx,
    ];
    expect(actionCenters, isNotEmpty);
    expect(
      actionCenters.every((center) => center == actionCenters.first),
      isTrue,
    );
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
        'notification switches use native adaptive styling in ${testCase.name} mode',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme.copyWith(platform: TargetPlatform.iOS),
          home: const TeamNotificationDetailPage(teamName: 'FC Barcelona'),
        ),
      );
      await tester.pump();

      final offSwitches = tester
          .widgetList<Switch>(find.byType(Switch))
          .where((toggle) => !toggle.value);
      expect(offSwitches, isNotEmpty);
      for (final toggle in offSwitches) {
        expect(toggle.inactiveThumbColor, isNull);
        expect(toggle.inactiveTrackColor, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final testCase in <({String name, Key key, Widget sheet})>[
    (
      name: 'following teams',
      key: const ValueKey('profile-team-edit-sheet'),
      sheet: EditFollowingTeamsSheet(
        repository: _StaticFollowingTeamsRepository(),
        initialTeams: const [Team(teamId: 83, name: 'FC Barcelona')],
        initialFavoriteTeamId: 83,
      ),
    ),
    (
      name: 'following players',
      key: const ValueKey('following-players-sheet'),
      sheet: const FollowingPlayersEditorSheet(players: []),
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

        final sheet = tester.widget(find.byKey(testCase.key));
        final searchKey = testCase.name == 'following teams'
            ? const ValueKey('profile-team-edit-search')
            : const ValueKey('following-players-search');
        final search = tester.widget<Container>(find.byKey(searchKey));
        expect(
            sheet is Material
                ? sheet.color
                : ((sheet as Container).decoration as BoxDecoration).color,
            themeCase.sheet);
        expect((search.decoration as BoxDecoration).color, themeCase.search);
        expect(
          (search.decoration as BoxDecoration).borderRadius,
          BorderRadius.circular(8),
        );
        expect(search.clipBehavior, Clip.antiAlias);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('following player search fades while scrolling at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: FollowingPlayersEditorSheet(
            players: const [],
            repository: _ManyPlayerCandidatesRepository(),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), 'E');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final top = find.byKey(const ValueKey('following-search-top-fade'));
      final bottom = find.byKey(const ValueKey('following-search-bottom-fade'));
      expect(tester.widget<ShaderMask>(top).blendMode, BlendMode.dst);
      expect(tester.widget<ShaderMask>(bottom).blendMode, BlendMode.dstIn);

      await tester.drag(
        find.descendant(of: bottom, matching: find.byType(ListView)),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ShaderMask>(top).blendMode, BlendMode.dstIn);
      expect(tester.widget<ShaderMask>(bottom).blendMode, BlendMode.dstIn);
      await tester.drag(
        find.descendant(of: bottom, matching: find.byType(ListView)),
        const Offset(0, -2400),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ShaderMask>(bottom).blendMode, BlendMode.dst);
      expect(tester.takeException(), isNull);
    });
  }
}

class _ManyPlayerCandidatesRepository extends FakePlayerDetailRepository {
  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) =>
      throw UnimplementedError();

  @override
  Future<List<PlayerCandidate>> search(String query) async => [
        for (var index = 1; index <= 20; index++)
          (id: index, name: 'Player $index', image: null),
      ];
}

class _StaticFollowingTeamsRepository implements FollowingTeamsRepository {
  final ValueNotifier<List<Team>> _cache = ValueNotifier(const []);

  @override
  ValueListenable<List<Team>> get cachedTeams => _cache;

  @override
  Future<List<Team>> load() async => _cache.value;

  @override
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  }) async =>
      _cache.value;
}

class _StaticNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  @override
  Future<NotificationPreferenceSnapshot> load() async =>
      const NotificationPreferenceSnapshot();

  @override
  Future<void> saveGlobal(GlobalNotificationPreferences preferences) async {}

  @override
  Future<void> saveTeam(
    int teamId,
    TeamNotificationPreferences preferences,
  ) async {}

  @override
  Future<void> applyTeamToAll(
    Iterable<int> teamIds,
    TeamNotificationPreferences preferences,
  ) async {}

  @override
  Future<void> applyNewBetsToAll(
    Iterable<int> teamIds,
    bool enabled,
  ) async {}

  @override
  Future<void> savePlayer(
    int playerId,
    PlayerNotificationPreferences preferences,
  ) async {}

  @override
  Future<void> applyPlayerToAll(
    Iterable<int> playerIds,
    PlayerNotificationPreferences preferences,
  ) async {}
}
