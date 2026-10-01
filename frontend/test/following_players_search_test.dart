import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/models/player_detail.dart';

import 'support/player_detail_fixture.dart';
import 'support/player_directory_fixture.dart';

const _pedri = (id: 37288001, name: 'Pedri', image: null);

class _SearchRepository extends FakePlayerDetailRepository {
  final pending = <Completer<List<PlayerCandidate>>>[];

  @override
  Future<List<PlayerCandidate>> search(String query) {
    searchQueries.add(query);
    final request = Completer<List<PlayerCandidate>>();
    pending.add(request);
    return request.future;
  }
}

Future<void> _pump(WidgetTester tester, _SearchRepository repository,
    {FakeFollowingPlayersRepository? following}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = PlayerFollowingController(
      repository: following ?? FakeFollowingPlayersRepository());
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: app_style.whitetheme,
    home: Scaffold(
      body: PlayerFavorites(
        controller: controller,
        searchRepository: repository,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Edit favorites'));
  await tester.pumpAndSettle();
}

Future<void> _query(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
      'Korean typing sends one final query and saves the selected player',
      (tester) async {
    final repository = _SearchRepository();
    final following = FakeFollowingPlayersRepository();
    await _pump(tester, repository, following: following);

    for (final query in ['ㅍ', '페', '펟', '페드', '페들', '페드리']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(repository.searchQueries, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    expect(repository.searchQueries, ['페드리']);
    expect(find.byType(FootballLoadingIndicator), findsOneWidget);

    repository.pending.single.complete([_pedri]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedri'));
    await tester.pump();
    await tester.tap(find.text('UPDATE'));
    await tester.pumpAndSettle();
    expect(following.saved, [1, _pedri.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed search is visible and retry recovers the same query',
      (tester) async {
    final repository = _SearchRepository();
    await _pump(tester, repository);
    await _query(tester, '페드리');
    repository.pending.single.completeError(
        http.ClientException('API request failed with status 500.'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load players · Retry'), findsOneWidget);
    expect(find.text('No players found'), findsNothing);
    await tester.tap(find.text('Could not load players · Retry'));
    await tester.pump();
    expect(repository.searchQueries, ['페드리', '페드리']);
    repository.pending.last.complete([_pedri]);
    await tester.pumpAndSettle();
    expect(find.text('Pedri'), findsOneWidget);
    expect(find.text('Could not load players · Retry'), findsNothing);
  });

  testWidgets('no matches are distinguished from a failed request',
      (tester) async {
    final repository = _SearchRepository();
    await _pump(tester, repository);
    await _query(tester, 'unknown');
    repository.pending.single.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No players found'), findsOneWidget);
    expect(find.text('Could not load players · Retry'), findsNothing);
  });

  testWidgets('selection and composing changes do not repeat the same query',
      (tester) async {
    final repository = _SearchRepository();
    await _pump(tester, repository);
    await _query(tester, '페드리');
    repository.pending.single.complete([_pedri]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedri'));

    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.value = const TextEditingValue(
      text: '페드리',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 3),
    );
    field.controller!.value = field.controller!.value.copyWith(
      selection: const TextSelection.collapsed(offset: 3),
      composing: TextRange.empty,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.searchQueries, ['페드리']);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);

    await _query(tester, 'another');
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    await tester.tap(find.descendant(
      of: find.byType(TextField),
      matching: find.byIcon(Icons.close),
    ));
    repository.pending.last.complete([_pedri]);
    await tester.pumpAndSettle();
    expect(find.text('Pedri'), findsNothing);
    expect(find.text('Could not load players · Retry'), findsNothing);
  });

  testWidgets('closing the editor cancels the pending search', (tester) async {
    final repository = _SearchRepository();
    await _pump(tester, repository);
    await tester.enterText(find.byType(TextField), '페드리');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.searchQueries, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
