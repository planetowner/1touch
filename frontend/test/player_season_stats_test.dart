import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/anal.dart';
import 'package:onetouch/screens/player_comparison_screen.dart';

import 'support/app_catalog.dart';
import 'support/player_detail_fixture.dart';

class _SampledStatsRepository extends FakePlayerDetailRepository {
  PlayerDetail detail(int playerId, {int? seasonId}) {
    final json = playerDetailJson(playerId: playerId, seasonId: seasonId);
    final analysis = json['analysis'] as Map<String, dynamic>;
    final seed = Map<String, dynamic>.from(
        analysis['categories'][0]['metrics'][0] as Map);
    final first = playerId == 1;
    final rows = [
      {
        ...seed,
        'code': 'passes',
        'label': 'Passes completed / attempted',
        'kind': 'pair',
        'value': null,
        'numerator': first ? 391 : 220,
        'denominator': first ? 423 : 243,
        'per90': first ? 391 * 90 / 501 : 220 * 90 / 529,
        'observed_matches': 7,
        'total_matches': 7,
      },
      {
        ...seed,
        'code': 'key_passes',
        'label': 'Key passes',
        'kind': 'count',
        'value': first ? null : 17,
        'per90': first ? 15 * 90 / 354 : 17 * 90 / 529,
        'observed_matches': first ? 5 : 7,
        'total_matches': 7,
      },
      {
        ...seed,
        'code': 'long_ball_success_rate',
        'label': 'Long ball success rate',
        'kind': 'percentage',
        'value': first ? 75 : 50,
        'per90': null,
        'observed_matches': 7,
        'total_matches': 7,
      },
      {
        ...seed,
        'code': 'interceptions',
        'label': 'Interceptions',
        'kind': 'count',
        'value': first ? null : 2,
        'per90': first ? null : 0,
        'observed_matches': first ? 0 : 7,
        'total_matches': 7,
      },
    ];
    analysis['categories'] = [
      {'code': 'build_up', 'label': 'Build Up', 'metrics': rows}
    ];
    analysis['top_stats'] = rows.take(3).toList();
    return playerDetailFromJson(json);
  }

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async =>
      detail(playerId, seasonId: seasonId);
}

void main() {
  setUpAppCatalog();

  test('season presentation uses successful counts, rates, zero and absence',
      () {
    final rows =
        _SampledStatsRepository().detail(1).analysis!.categories[0].metrics;
    final passes = playerSeasonStat(rows[0]);
    expect(passes.label, 'Accurate passes');
    expect(passes.text, '70.24');
    expect(passes.unit, 'per 90');
    expect(playerSeasonStat(rows[1]).text, '3.81');
    expect(playerSeasonStat(rows[2]).text, '75%');
    expect(playerSeasonStat(rows[3]).text, '—');
    expect(playerSeasonStat(null).value, isNull);
    final zero =
        _SampledStatsRepository().detail(3).analysis!.categories[0].metrics[3];
    expect(playerSeasonStat(zero).text, '0');
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final locale in [const Locale('en'), const Locale('ko')]) {
      testWidgets(
          'comparison shows sampled per90 and percentages at $size $locale',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          theme: locale.languageCode == 'en' ? darktheme : whitetheme,
          home: PlayerComparisonScreen(
              initialPlayerId: '1', repository: _SampledStatsRepository()),
        ));
        await tester.pumpAndSettle();
        await tester.tap(
            find.text(translateMessage(locale, 'PLAYER {slot}', {'slot': 2})));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Player 3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('26/27'));
        await tester.pumpAndSettle();

        final card =
            find.byKey(const ValueKey('comparison-stat-card-Build Up'));
        Finder value(String text) =>
            find.descendant(of: card, matching: find.text(text));
        for (final text in [
          '70.24',
          '37.43',
          '3.81',
          '2.89',
          '75%',
          '50%',
          '—',
          '0'
        ]) {
          expect(value(text), findsOneWidget);
        }
        expect(value('391'), findsNothing);
        expect(value('Passes completed / attempted'), findsNothing);
        expect(value(locale.languageCode == 'ko' ? '패스 성공' : 'Accurate Passes'),
            findsOneWidget);
        expect(value(translateMessage(locale, 'per 90')), findsNWidgets(3));
        expect(
            value(translateMessage(
                locale,
                'Based on {observed}/{total} matches',
                {'observed': 5, 'total': 7})),
            findsOneWidget);

        final firstPass =
            find.byKey(const ValueKey('comparison-stat-first-key_passes'));
        final secondPass =
            find.byKey(const ValueKey('comparison-stat-second-key_passes'));
        expect(
            tester.getSize(firstPass).width / tester.getSize(secondPass).width,
            closeTo((15 / 354) / (17 / 529), 0.001));
        final firstMissing =
            find.byKey(const ValueKey('comparison-stat-first-interceptions'));
        final secondMissing =
            find.byKey(const ValueKey('comparison-stat-second-interceptions'));
        expect(tester.getSize(firstMissing).width,
            tester.getSize(secondMissing).width);
        Color? background(Finder finder) => tester
            .widget<Container>(
                find.descendant(of: finder, matching: find.byType(Container)))
            .color;
        expect(background(firstMissing), background(secondMissing));

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(card).width, lessThanOrEqualTo(size.width));
      });

      testWidgets(
          'analysis shares per90 labels and sample coverage at $size $locale',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final detail = _SampledStatsRepository().detail(1);
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          theme: locale.languageCode == 'en' ? darktheme : whitetheme,
          home: Scaffold(
              body: PlayerDetailScope(
            store: PlayerDetailStore(playerId: 1, initial: detail),
            child: const AnalysisTab(playerId: 1),
          )),
        ));
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('player-top-stats-card'));
        for (final text in ['70.24', '3.81', '75%']) {
          expect(find.descendant(of: card, matching: find.text(text)),
              findsOneWidget);
        }
        expect(
            find.text(
                locale.languageCode == 'ko' ? '패스 성공' : 'Accurate Passes'),
            findsOneWidget);
        expect(
            find.text(translateMessage(
                locale,
                'Based on {observed}/{total} matches',
                {'observed': 5, 'total': 7})),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
