import 'package:flutter/material.dart';
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
    // Two separate boxes stacked flush so they read as one connected card:
    // a lighter top box (only the top corners rounded) and a darker bottom box
    // (only the bottom corners rounded). The colour change is the divider.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top box: opponent crest + result/score + competition.
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF3D3D3D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.black,
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
              const Spacer(),
              Text(competition, style: Eyebrow.style),
            ],
          ),
        ),
        // Bottom box: stat label + value pills, then the rating badge.
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ...stats.map((stat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stat["label"]!,
                        style: Eyebrow.style,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x66090A0A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(stat["value"]!, style: Body2_b.style),
                      ),
                    ],
                  ),
                );
              }),
              const Spacer(),
              // Rating badge sits on the app's near-black chip, distinct from
              // the grey stat pills.
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A0A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(rating, style: Body2_b.style),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
