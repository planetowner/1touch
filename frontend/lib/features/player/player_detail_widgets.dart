import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';

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
  const PlayerSection(
      {super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: Body2_b.style)),
          if (trailing != null) trailing!
        ]),
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
          header ? 'MP' : '${record!.appearances}',
          header
              ? 'WR'
              : record!.winRate == null
                  ? '—'
                  : '${playerNumber(record!.winRate, decimals: 1)}%',
          header ? 'Rating' : record!.rating?.toStringAsFixed(1) ?? '—'
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
  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final badgeColor = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightGrey
        : appColors.subtleBackground;
    final muted = Body2.style.copyWith(color: appColors.mutedForeground);
    return PlayerSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(children: [
        Row(children: [
          Expanded(flex: 3, child: Text('League', style: muted)),
          Expanded(
              flex: 2,
              child: Text('MP', textAlign: TextAlign.center, style: muted)),
          Expanded(
              flex: 2,
              child: Text('WR', textAlign: TextAlign.center, style: muted)),
          Expanded(
              flex: 2,
              child: Text('Rating', textAlign: TextAlign.right, style: muted)),
        ]),
        const SizedBox(height: 12),
        Divider(color: appColors.divider, height: 1),
        if (competitions.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No competitions this season')),
        for (var index = 0; index < competitions.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text(competitions[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Heading5.style)),
              Expanded(
                  flex: 2,
                  child: Text('${competitions[index].record.appearances}',
                      textAlign: TextAlign.center, style: Heading5.style)),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                              competitions[index]
                                      .record
                                      .rating
                                      ?.toStringAsFixed(1) ??
                                  '—',
                              style: Heading5.style)))),
            ]),
          ),
          if (index != competitions.length - 1)
            Divider(color: appColors.divider, height: 1),
        ],
      ]),
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
              result: match.live ? 'LIVE' : match.result ?? '—',
              score: '${match.homeScore ?? '—'} - ${match.awayScore ?? '—'}',
              competition:
                  '${match.competition}${match.round == null ? '' : ' / ${match.round}'}',
              opponentName: match.opponent,
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
                  title: category.label.toUpperCase(),
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
            Expanded(child: Text(stat.metric.label, style: Body2_b.style)),
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
                '#${stat.rank} / ${stat.referenceCount} · ${stat.metric.kind == 'percentage' ? 'success rate' : 'per 90'}',
                style: Eyebrow.style),
          if (stat.observedMatches < stat.totalMatches)
            Text(
                'Available in ${stat.observedMatches}/${stat.totalMatches} matches',
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
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(playerMetricValue(left.metric),
                    style: Body2_b.style))),
        const SizedBox(width: 12),
        Expanded(
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                    right == null ? '—' : playerMetricValue(right.metric),
                    style: Body2_b.style))),
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
