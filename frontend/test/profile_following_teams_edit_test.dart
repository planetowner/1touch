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

        final teamRow = find.widgetWithText(ListTile, 'Real Madrid');
        expect(teamRow, findsOneWidget);
        if (target == 'logo') {
          final rowRect = tester.getRect(teamRow);
          await tester.tapAt(Offset(rowRect.left + 26, rowRect.center.dy));
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
    expect(find.textContaining('Favorite team up to 3 times in 7 days'),
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
  const _EditSheetHost({required this.repository});

  final FollowingTeamsRepository repository;

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
              initialTeams: const [
                Team(teamId: 83, name: 'FC Barcelona'),
                Team(teamId: 19, name: 'Arsenal'),
              ],
              initialFavoriteTeamId: 83,
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
