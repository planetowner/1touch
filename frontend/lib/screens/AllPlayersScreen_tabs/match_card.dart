import 'package:onetouch/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

String _singularMatchStatLabel(BuildContext context, String label) {
  final localized = appStatLabel(context, label);
  if (Localizations.localeOf(context).languageCode != 'en') return localized;
  return localized.replaceAllMapped(RegExp(r'\b[A-Za-z]+\b'), (match) {
    final word = match.group(0)!;
    final lower = word.toLowerCase();
    if (lower.length > 3 && lower.endsWith('ies')) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (lower.endsWith('sses') ||
        lower.endsWith('shes') ||
        lower.endsWith('ches') ||
        lower.endsWith('xes') ||
        lower.endsWith('zes')) {
      return word.substring(0, word.length - 2);
    }
    if (lower.length > 1 && lower.endsWith('s') && !lower.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  });
}

/// A single player match box, shared by the Overview "MATCHES" preview and the
/// Matches tab so every box follows the same detailed design:

class PlayerMatchCard extends StatelessWidget {
  final String result; // e.g. "DEF" / "WIN" / "DRAW"
  final String score; // e.g. "0 - 2"
  final String competition; // e.g. "League / Round"
  final String? againstLogo; // asset path, or null for the empty placeholder
  final List<Map<String, String>> stats; // [{"label": "Goal", "value": "1"}]
  final String rating; // e.g. "8.4"
  final bool remoteLogo;

  const PlayerMatchCard({
    super.key,
    required this.result,
    required this.score,
    required this.competition,
    required this.stats,
    required this.rating,
    this.againstLogo,
    this.remoteLogo = false,
  });

  /// Convenience for the map-shaped mock data used across the player tabs.
  factory PlayerMatchCard.fromMap(Map<String, dynamic> match) {
    return PlayerMatchCard(
      result: match["result"] as String,
      score: match["score"] as String,
      competition: match["competition"] as String,
      againstLogo: match["againstLogo"] as String?,
      stats: (match["stats"] as List).cast<Map<String, String>>(),
      rating: match["rating"] as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topColor = isDark ? const Color(0xFF3D3D3D) : AppPalette.white;
    final bottomColor =
        isDark ? AppPalette.darkGrey : appColors.subtleBackground;
    final statColor = isDark ? const Color(0x66090A0A) : AppPalette.white;
    // Two separate boxes stacked flush so they read as one connected card:
    // a lighter top box (only the top corners rounded) and a darker bottom box
    // (only the bottom corners rounded). The colour change is the divider.
    return Container(
      key: const ValueKey('player-match-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: appCardShadows(context),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Top box: opponent crest + result/score + competition.
        Container(
          key: const ValueKey('player-match-card-top'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: topColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                SizedBox(
                  key: const ValueKey('player-match-logo'),
                  width: 32,
                  height: 32,
                  child: againstLogo != null
                      ? remoteLogo
                          ? Image.network(againstLogo!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink())
                          : Image.asset(
                              againstLogo!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            )
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.62,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result,
                        key: const ValueKey('player-match-result'),
                        maxLines: 1,
                        softWrap: false,
                        style: Heading5.style,
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          '( $score )',
                          key: const ValueKey('player-match-score'),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: Heading5.style,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      normalizeCompetitionDisplayLabel(competition),
                      key: const ValueKey('player-match-competition'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Eyebrow.style,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom box: stat label + value pills, then the rating badge.
        Container(
          key: const ValueKey('player-match-card-bottom'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: bottomColor,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  children: [
                    for (var index = 0; index < stats.length; index++) ...[
                      Flexible(
                        child: Row(
                          key: ValueKey(
                              'player-match-stat-pair-${stats[index]["label"]}'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _singularMatchStatLabel(
                                    context, stats[index]["label"]!),
                                textAlign: TextAlign.left,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Eyebrow.style,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              key: ValueKey(
                                  'player-match-stat-value-${stats[index]["label"]}'),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: statColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(stats[index]["value"]!,
                                  style: Body2_b.style),
                            ),
                          ],
                        ),
                      ),
                      if (index != stats.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
              ),
              if (stats.isNotEmpty) const SizedBox(width: 16),
              // Rating badge sits on the app's near-black chip, distinct from
              // the grey stat pills.
              Container(
                key: const ValueKey('player-match-rating'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppPalette.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rating,
                  style: Body2_b.style.copyWith(color: AppPalette.white),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
