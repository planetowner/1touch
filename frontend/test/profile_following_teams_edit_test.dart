import 'package:onetouch/models/profile_change_limit_exception.dart';
import 'support/app_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/models/team.dart';

void main() {
  setUpAppCatalog();
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
        'sheet keeps player editor height for two search results at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: _EditSheetHost(
          repository: _RecordingFollowingTeamsRepository(),
          initialTeams: const [
            Team(teamId: 83, name: 'FC Barcelona'),
            Team(teamId: 19, name: 'Arsenal'),
            Team(teamId: 9, name: 'Manchester City'),
            Team(teamId: 503, name: 'FC Bayern München'),
            Team(teamId: 3468, name: 'Atlético Madrid'),
          ],
        ),
      ));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey('profile-team-edit-sheet'));
      final topFade = find.byKey(const ValueKey('profile-team-edit-top-fade'));
      final fade = find.byKey(const ValueKey('profile-team-edit-bottom-fade'));
      final search = find.byKey(const ValueKey('profile-team-edit-search'));
      final fullHeight = tester.getSize(sheet).height;
      expect(fullHeight, closeTo(size.height * 0.92, 1));
      expect(tester.getRect(search).bottom, tester.getRect(topFade).top);
      expect(tester.getRect(fade).top, tester.getRect(search).bottom);
      final firstTeamLogo = find
          .descendant(
            of: find.byKey(const ValueKey(83)),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.width == 52 &&
                  widget.height == 52,
            ),
          )
          .first;
      expect(tester.getRect(firstTeamLogo).top - tester.getRect(search).bottom,
          closeTo(24, 1));
      final update = find.widgetWithText(ElevatedButton, 'UPDATE');
      expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dst);
      expect(tester.widget<ShaderMask>(fade).blendMode,
          size.height < 800 ? BlendMode.dstIn : BlendMode.dst);
      if (size.height > 800) {
        final teamList = find.descendant(
          of: sheet,
          matching: find.byType(ReorderableListView),
        );
        expect(
          tester.getRect(update).top - tester.getRect(teamList).bottom,
          closeTo(16, 1),
        );
      }
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'Manchester');
      await tester.pumpAndSettle();
      expect(tester.getRect(search).bottom, tester.getRect(topFade).top);
      expect(tester.getRect(fade).top, tester.getRect(search).bottom);
      final teamList = find.descendant(
        of: sheet,
        matching: find.byType(ListView),
      );
      final results = find.descendant(
        of: teamList,
        matching: find.byType(InkWell),
      );
      expect(results, findsNWidgets(2));
      final firstResultLogo = find
          .descendant(
            of: results.first,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.width == 52 &&
                  widget.height == 52,
            ),
          )
          .first;
      expect(
          tester.getRect(firstResultLogo).top - tester.getRect(search).bottom,
          closeTo(24, 1));
      expect(tester.getSize(sheet).height, closeTo(fullHeight, 1));
      expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dst);
      expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dst);
      expect(
        tester.getRect(update).top - tester.getRect(teamList).bottom,
        closeTo(16, 1),
      );
      expect(tester.takeException(), isNull);

      if (size.width == 320) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(update, findsOneWidget);
        expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dstIn);
      }
    });
  }

  testWidgets('team list fade clears after scrolling to the last team',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: _EditSheetHost(
        repository: _RecordingFollowingTeamsRepository(),
        initialTeams: const [
          Team(teamId: 83, name: 'FC Barcelona'),
          Team(teamId: 19, name: 'Arsenal'),
          Team(teamId: 9, name: 'Manchester City'),
          Team(teamId: 503, name: 'FC Bayern München'),
          Team(teamId: 3468, name: 'Atlético Madrid'),
        ],
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final fade = find.byKey(const ValueKey('profile-team-edit-bottom-fade'));
    final topFade = find.byKey(const ValueKey('profile-team-edit-top-fade'));
    final search = find.byKey(const ValueKey('profile-team-edit-search'));
    final list = find.descendant(
      of: fade,
      matching: find.byType(ReorderableListView),
    );
    expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dst);
    expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dstIn);
    await tester.drag(list, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dstIn);
    expect(tester.getRect(list).top, tester.getRect(search).bottom);
    expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dst);
    await tester.drag(list, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dst);
    expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dstIn);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search result fade clears after scrolling to the last result',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: _EditSheetHost(repository: _RecordingFollowingTeamsRepository()),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();

    final fade = find.byKey(const ValueKey('profile-team-edit-bottom-fade'));
    final topFade = find.byKey(const ValueKey('profile-team-edit-top-fade'));
    final search = find.byKey(const ValueKey('profile-team-edit-search'));
    final list = find.descendant(
      of: fade,
      matching: find.byType(ListView),
    );
    expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dst);
    expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dstIn);
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dstIn);
    expect(tester.getRect(list).top, tester.getRect(search).bottom);
    expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dst);
    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.widget<ShaderMask>(topFade).blendMode, BlendMode.dst);
    expect(tester.widget<ShaderMask>(fade).blendMode, BlendMode.dstIn);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final theme in [app_style.darktheme, app_style.whitetheme]) {
      testWidgets(
          'team rule notice fits and dismisses at $size in ${theme.brightness}',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home:
              _EditSheetHost(repository: _RecordingFollowingTeamsRepository()),
        ));
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();

        final notice = find.byKey(const ValueKey('team-edit-rule-notice'));
        final message = find
            .text('You can change your favorite team up to twice in 14 days.');
        final close = find.descendant(
          of: notice,
          matching: find.byKey(const ValueKey('app-rule-notice-close')),
        );
        expect(notice, findsOneWidget);
        expect(message, findsOneWidget);
        expect(tester.getRect(message).left - tester.getRect(notice).left, 24);
        expect(tester.getRect(notice).right - tester.getRect(close).right, 14);
        expect(tester.getSize(close), const Size(40, 40));
        final icon = find.descendant(
          of: close,
          matching: find.byIcon(Icons.close),
        );
        expect(tester.widget<Icon>(icon).size, 20);
        final expectedBackground = theme.brightness == Brightness.dark
            ? app_style.AppPalette.white
            : app_style.AppPalette.black;
        final expectedForeground = theme.brightness == Brightness.dark
            ? const Color(0xFF090A0A)
            : app_style.AppPalette.white;
        final background = find.descendant(
          of: notice,
          matching: find.byType(ColoredBox),
        );
        expect(tester.widget<ColoredBox>(background).color, expectedBackground);
        expect(tester.widget<Text>(message).style?.color, expectedForeground);
        expect(tester.widget<Icon>(icon).color, expectedForeground);
        expect(tester.widget<Text>(message).style?.fontSize, 12);
        expect(tester.widget<Text>(message).style?.height, 1.30);
        expect(tester.takeException(), isNull);

        await tester.tap(message);
        await tester.pumpAndSettle();
        expect(notice, findsOneWidget);
        await tester.tapAt(tester.getTopLeft(close) + const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
        expect(find.byKey(const ValueKey('profile-team-edit-sheet')),
            findsOneWidget);
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final target in ['name', 'logo']) {
      testWidgets('selects a searched team by tapping its $target at $size',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _RecordingFollowingTeamsRepository();
        await tester.pumpWidget(MaterialApp(
          theme: app_style.whitetheme,
          home: _EditSheetHost(repository: repository),
        ));
        await tester.tap(find.text('OPEN'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Real Madrid');
        await tester.pumpAndSettle();

        final teamRow = find.byKey(const ValueKey('team-search-result-3468'));
        expect(teamRow, findsOneWidget);
        if (target == 'logo') {
          final logo = find
              .descendant(
                of: teamRow,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is SizedBox &&
                      widget.width == 52 &&
                      widget.height == 52,
                ),
              )
              .first;
          await tester.tap(logo);
        } else {
          await tester.tap(find.descendant(
            of: teamRow,
            matching: find.text('Real Madrid'),
          ));
        }
        await tester.pump();

        expect(
          find.descendant(
            of: teamRow,
            matching: find.byIcon(Icons.radio_button_checked),
          ),
          findsOneWidget,
        );
        expect(
            tester
                .widget<ElevatedButton>(find.widgetWithText(
                  ElevatedButton,
                  'UPDATE',
                ))
                .onPressed,
            isNotNull);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('saves edited following teams through the API repository',
      (tester) async {
    final repository = _RecordingFollowingTeamsRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: _EditSheetHost(repository: repository),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pump();
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();

    expect(repository.savedTeamIds, [19]);
    expect(repository.savedFavoriteTeamId, 19);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('shows a replacement second team on Home at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _RecordingFollowingTeamsRepository();

      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: _EditSheetHost(repository: repository),
      ));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Manchester City');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('team-search-result-9')));
      await tester.pump();
      await tester.ensureVisible(find.text('UPDATE'));
      await tester.tap(find.text('UPDATE'));
      await tester.pumpAndSettle();

      expect(repository.savedTeamIds, [83, 9]);
      expect(repository.savedFavoriteTeamId, 83);
      expect(currentUserPreferences.favoriteTeamId.value, 83);
      expect(currentUserPreferences.viewedTeamId.value, 9);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps the sheet open when the backend rejects the update',
      (tester) async {
    final repository = _RecordingFollowingTeamsRepository(
      error: ProfileChangeLimitException(
        maxChanges: 3,
        windowDays: 7,
        availableAt: DateTime.utc(2026, 9, 20),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: _EditSheetHost(repository: repository),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pump();
    await tester.tap(find.text('UPDATE'));
    await tester.pump();

    expect(
        find.byKey(const ValueKey('profile-team-edit-sheet')), findsOneWidget);
    expect(find.textContaining('Primary team up to 3 times in 7 days'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the reordered first team across Home preferences',
      (tester) async {
    final repository = _RecordingFollowingTeamsRepository();
    currentUserPreferences.viewTeam(83);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: _EditSheetHost(repository: repository),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    final firstHandle = find.descendant(
      of: find.byKey(const ValueKey(83)),
      matching: find.byIcon(Icons.drag_handle),
    );
    await tester.drag(firstHandle, const Offset(0, 180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();

    expect(repository.savedTeamIds, [19, 83]);
    expect(repository.savedFavoriteTeamId, 19);
    expect(currentUserPreferences.favoriteTeamId.value, 19);
    expect(currentUserPreferences.followedTeamIds.value, [19, 83]);
    expect(currentUserPreferences.viewedTeamId.value, 19);
    expect(tester.takeException(), isNull);
  });
}

class _EditSheetHost extends StatelessWidget {
  const _EditSheetHost(
      {required this.repository,
      this.initialTeams = const [
        Team(teamId: 83, name: 'FC Barcelona'),
        Team(teamId: 19, name: 'Arsenal'),
      ]});

  final FollowingTeamsRepository repository;
  final List<Team> initialTeams;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showModalBottomSheet<FollowingTeamsEditResult>(
            context: context,
            isScrollControlled: true,
            builder: (_) => EditFollowingTeamsSheet(
              repository: repository,
              initialTeams: initialTeams,
              initialFavoriteTeamId: initialTeams.first.teamId,
            ),
          ),
          child: const Text('OPEN'),
        ),
      ),
    );
  }
}

class _RecordingFollowingTeamsRepository implements FollowingTeamsRepository {
  _RecordingFollowingTeamsRepository({this.error});

  final Object? error;
  final ValueNotifier<List<Team>> _cache = ValueNotifier(const []);
  List<int>? savedTeamIds;
  int? savedFavoriteTeamId;

  @override
  ValueListenable<List<Team>> get cachedTeams => _cache;

  @override
  Future<List<Team>> load() async => _cache.value;

  @override
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  }) async {
    savedTeamIds = teamIds.toList();
    savedFavoriteTeamId = favoriteTeamId;
    final failure = error;
    if (failure != null) throw failure;

    final teams = savedTeamIds!
        .map((teamId) => Team(teamId: teamId, name: 'Team $teamId'))
        .toList(growable: false);
    _cache.value = teams;
    return teams;
  }
}
