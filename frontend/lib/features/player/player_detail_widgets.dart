import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PlayerRemoteImage extends StatelessWidget {
  const PlayerRemoteImage(this.url, {super.key, this.size = 28});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: url == null
          ? const Icon(Icons.person_outline)
          : Image.network(url!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_outline)));
}

class PlayerSection extends StatelessWidget {
  const PlayerSection({
    super.key,
    required this.title,
    required this.child,
    this.titleAccessory,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? titleAccessory;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                      child: Text(tr(context, title), style: Body2_b.style)),
                  if (titleAccessory != null) ...[
                    const SizedBox(width: 4),
                    titleAccessory!,
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ]);
}

class PlayerSurface extends StatelessWidget {
  const PlayerSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: AppColors.of(context).cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: appCardShadows(context)),
      child: child);
}

class PlayerRecordRow extends StatelessWidget {
  const PlayerRecordRow(
      {super.key,
      required this.label,
      required this.record,
      this.header = false});
  final Widget label;
  final PlayerRecord? record;
  final bool header;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(flex: 4, child: label),
        for (final text in [
          header ? tr(context, 'MP') : '${record!.appearances}',
          header
              ? 'WR'
              : record!.winRate == null
                  ? '—'
                  : '${playerNumber(record!.winRate, decimals: 1)}%',
          header
              ? tr(context, 'Rating')
              : record!.rating?.toStringAsFixed(1) ?? '—'
        ])
          Expanded(
              flex: 2,
              child: Text(text,
                  textAlign: TextAlign.center, style: Body2_b.style)),
      ]));
}

class PlayerCompetitionTable extends StatelessWidget {
  const PlayerCompetitionTable({super.key, required this.competitions});
  final List<PlayerCompetitionRecord> competitions;

  String _competitionLabel(
      BuildContext context, PlayerCompetitionRecord competition) {
    final shortCode = footballCatalog.competitions.value
        .where((item) => item.competitionId == competition.id)
        .firstOrNull
        ?.shortCode
        ?.trim();
    if (shortCode != null && shortCode.isNotEmpty) return shortCode;
    return competitionNameLabel(context, competition.id, competition.name);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerStyle = Body1.style.copyWith(
      color: isDark ? AppPalette.white : AppPalette.black,
    );
    return PlayerSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: [
          Container(
            key: const ValueKey('player-competition-header-surface'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: appColors.subtleBackground,
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text(
                    tr(context, 'League'),
                    key: const ValueKey('player-competition-league-header'),
                    textAlign: TextAlign.left,
                    style: headerStyle,
                  )),
              Expanded(
                  flex: 2,
                  child: Text(tr(context, 'MP'),
                      textAlign: TextAlign.center, style: headerStyle)),
              Expanded(
                  flex: 2,
                  child: Text('WR',
                      textAlign: TextAlign.center, style: headerStyle)),
              Expanded(
                  flex: 2,
                  child: Text(tr(context, 'Rating'),
                      textAlign: TextAlign.right, style: headerStyle)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(children: [
              if (competitions.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tr(context, 'No competitions this season'))),
              for (var index = 0; index < competitions.length; index++) ...[
                Row(
                  key: ValueKey(
                      'player-competition-row-${competitions[index].id}'),
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(
                            _competitionLabel(context, competitions[index]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: Heading5.style)),
                    Expanded(
                        flex: 2,
                        child: Text('${competitions[index].record.appearances}',
                            textAlign: TextAlign.center,
                            style: Heading5.style)),
                    Expanded(
                        flex: 2,
                        child: Text(
                            competitions[index].record.winRate == null
                                ? '—'
                                : '${playerNumber(competitions[index].record.winRate, decimals: 0)}%',
                            textAlign: TextAlign.center,
                            style: Heading5.style)),
                    Expanded(
                        flex: 2,
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                                key: ValueKey(
                                    'player-competition-rating-${competitions[index].id}'),
                                height: 32,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: AppPalette.black,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                        competitions[index]
                                                .record
                                                .rating
                                                ?.toStringAsFixed(1) ??
                                            '—',
                                        style: Body1_b.style.copyWith(
                                          color: AppPalette.white,
                                          height: 1.3,
                                        )),
                                  ],
                                )))),
                  ],
                ),
                if (index != competitions.length - 1) const SizedBox(height: 8),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class PlayerDetailMatchCard extends StatelessWidget {
  const PlayerDetailMatchCard({super.key, required this.match});
  final PlayerDetailMatch match;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
          onTap: () => context.push(
              '/match/${match.id}?status=${match.live ? 'live' : 'past'}'),
          child: PlayerMatchCard(
              result: match.live ? tr(context, 'LIVE') : match.result ?? '—',
              score: '${match.homeScore ?? '—'} - ${match.awayScore ?? '—'}',
              competition:
                  '${competitionNameLabel(context, match.competitionId, match.competition)}${match.round == null ? '' : ' / ${match.round}'}',
              opponentName: teamNameLabel(
                  context, match.opponentTeamId, match.opponent ?? '—'),
              againstLogo: match.opponentImage,
              remoteLogo: true,
              stats: [
                for (final metric in match.metrics)
                  {'label': metric.label, 'value': playerMetricValue(metric)}
              ],
              rating: match.rating?.toStringAsFixed(1) ?? '—')));
}

class PlayerStatCategories extends StatelessWidget {
  const PlayerStatCategories(
      {super.key, required this.categories, this.comparison});
  final List<PlayerSeasonCategory> categories;
  final List<PlayerSeasonCategory>? comparison;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final category in categories)
          Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: PlayerSection(
                  title: playerCategoryLabel(context, category.label)
                      .toUpperCase(),
                  child: PlayerSurface(
                      key: ValueKey('player-category-${category.code}'),
                      child: Column(children: [
                        for (final stat in category.metrics)
                          _row(context, stat),
                      ])))),
      ]);

  Widget _row(BuildContext context, PlayerSeasonMetric stat) {
    final other = comparison
        ?.expand((c) => c.metrics)
        .where((m) => m.metric.code == stat.metric.code)
        .firstOrNull;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child:
                    Text(tr(context, stat.metric.label), style: Body2_b.style)),
            if (comparison == null)
              Text(playerMetricValue(stat.metric), style: Body2_b.style)
          ]),
          const SizedBox(height: 8),
          if (comparison == null)
            LinearProgressIndicator(
                value: (stat.percentile ?? 0) / 100,
                minHeight: 8,
                color: const Color(0xFF5C92FF),
                backgroundColor: AppColors.of(context).subtleBackground)
          else
            _comparisonBar(stat, other),
          if (comparison == null && stat.rank != null)
            Text(
                '#${stat.rank} / ${stat.referenceCount} · ${stat.metric.kind == 'percentage' ? tr(context, 'success rate') : tr(context, 'per 90')}',
                style: Eyebrow.style),
          if (stat.observedMatches < stat.totalMatches)
            Text(
                tr(context, 'Available in {observed}/{total} matches', {
                  'observed': stat.observedMatches,
                  'total': stat.totalMatches
                }),
                style: Eyebrow.style),
        ]));
  }

  Widget _comparisonBar(PlayerSeasonMetric left, PlayerSeasonMetric? right) {
    final a =
        left.metric.kind == 'pair' ? left.metric.numerator : left.metric.value;
    final b = right?.metric.kind == 'pair'
        ? right?.metric.numerator
        : right?.metric.value;
    final share = a != null && b != null && a + b > 0 ? a / (a + b) : null;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          child: Text(
            playerMetricValue(left.metric),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Body2_b.style,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            right == null ? '—' : playerMetricValue(right.metric),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Body2_b.style,
          ),
        ),
      ]),
      const SizedBox(height: 4),
      if (share != null)
        Row(children: [
          Expanded(
              flex: (share * 10000).round(),
              child: Container(height: 16, color: const Color(0xFF199FD6))),
          Expanded(
              flex: ((1 - share) * 10000).round(),
              child: Container(height: 16, color: const Color(0xFFD64F19))),
        ]),
    ]);
  }
}
