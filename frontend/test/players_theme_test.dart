import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/screens/PlayerScreen.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'support/player_detail_fixture.dart';
import 'support/player_directory_fixture.dart';

void main() {
  Future<void> pump(WidgetTester tester,
      {Size size = const Size(430, 932),
      bool dark = false,
      FakePlayerDirectoryRepository? repository,
      FakeFollowingPlayersRepository? following}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: dark ? app_style.darktheme : app_style.whitetheme,
        home: Players(
            repository: repository ?? FakePlayerDirectoryRepository(),
            detailRepository: FakePlayerDetailRepository(),
            followingController: PlayerFollowingController(
                repository: following ?? FakeFollowingPlayersRepository()))));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets('real player directory fits $size dark=$dark',
          (tester) async {
        await pump(tester, size: size, dark: dark);
        expect(find.text('Favorite player'), findsOneWidget);
        expect(find.text('Ranked player 1'), findsOneWidget);
        expect(find.text('Ranked player 6'), findsNothing);
        expect(find.text('All seasons'), findsNothing);
        expect(find.textContaining('Ranking data unavailable: Bundesliga'),
            findsOneWidget);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(find.text('Improving player'), findsOneWidget);
        expect(find.text('+2.20'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'league and position filters reach the API and unavailable league stays empty',
      (tester) async {
    final repository = FakePlayerDirectoryRepository();
    await pump(tester, repository: repository);
    expect(repository.calls.single, (league: null, position: null, offset: 0));
    await tester.tap(find.byTooltip('Ranking filters'));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>))
        .onChanged!(82);
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('GK');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (league: 82, position: 'GK', offset: 0));
    expect(find.text('No ranking data for these filters'), findsOneWidget);
    expect(find.text('Ranked player 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'favorite editor cancels without saving and saves authoritative list',
      (tester) async {
    final following = FakeFollowingPlayersRepository();
    await pump(tester, following: following);
    await tester.tap(find.byTooltip('Edit favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove player'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(following.saved, isNull);
    expect(find.text('Favorite player'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit favorites'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove player'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(following.saved, isEmpty);
    expect(find.text('Add favorite players'), findsOneWidget);
  });
  testWidgets('directory retry restores real results', (tester) async {
    final repository = FakePlayerDirectoryRepository()..fail = true;
    await pump(tester, repository: repository);
    expect(find.text('Could not load ranking · Retry'), findsOneWidget);
    expect(find.text('Ranked player 1'), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Could not load ranking · Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ranked player 1'), findsOneWidget);
  });
}
