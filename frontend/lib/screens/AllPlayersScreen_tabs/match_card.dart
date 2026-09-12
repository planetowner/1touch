import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

/// A single player match box, shared by the Overview "MATCHES" preview and the
/// Matches tab so every box follows the same detailed design:

class PlayerMatchCard extends StatelessWidget {
  final String result; // e.g. "DEF" / "WIN" / "DRAW"
  final String score; // e.g. "0 - 2"
  final String competition; // e.g. "League / Round"
  final String? againstLogo; // asset path, or null for the empty placeholder
  final List<Map<String, String>> stats; // [{"label": "Goal", "value": "1"}]
  final String rating; // e.g. "8.4"

  const PlayerMatchCard({
    super.key,
    required this.result,
    required this.score,
    required this.competition,
    required this.stats,
    required this.rating,
    this.againstLogo,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top box: opponent crest + result/score + competition.
        Container(
          key: const ValueKey('player-match-card-top'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: topColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.black : appColors.subtleBackground,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: againstLogo != null
                    ? Image.asset(
                        againstLogo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(result, style: Heading5.style),
              const SizedBox(width: 16),
              Text("( $score )", style: Heading5.style),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  competition,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Eyebrow.style,
                ),
              ),
            ],
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
              ...stats.map((stat) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stat["label"]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Eyebrow.style,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(stat["value"]!, style: Body2_b.style),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // Rating badge sits on the app's near-black chip, distinct from
              // the grey stat pills.
              Container(
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
      ],
    );
  }
}
