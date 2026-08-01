import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/features/player_image.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';

class PlayerOverviewTab extends StatelessWidget {
  final Player player;

  const PlayerOverviewTab({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content on top of background
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBlock(player),
              const SizedBox(height: 48),
              _buildBioStatsBlock(context),
              const SizedBox(height: 48),
              _buildCompetitionsBlock(),
              const SizedBox(height: 48),
              _buildMatchSummaryBlock(),
              const SizedBox(height: 48),
              _buildClubHistoryBlock(),
              const SizedBox(height: 144),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBlock(Player player) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${player.jerseyNumber}', style: Heading1.style),
            const SizedBox(height: 4),
            Text(player.positionLabel, style: Body1.style),
            const SizedBox(height: 8),
            Text(player.teamName, style: Body1.style),
            const SizedBox(height: 4),
            Text(
              '${player.nationality} ${player.nationalityFlag}',
              style: Body1.style,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          width: 145,
          height: 145,
          child: PlayerImage(
            player: player,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  Widget _buildBioStatsBlock(BuildContext context) {
    return PlayerBioStatsBlock(player: player);
  }

  Widget _buildCompetitionsBlock() {
    final season = player.seasonStats;
    final winRate = (52 + player.rankingScore % 30).round();
    final competitions = [
      {
        "name": player.leagueCode,
        "mp": "${season.appearances}",
        "wr": "$winRate%",
        "rating": season.rating.toStringAsFixed(1),
      },
      {
        "name": "UCL",
        "mp": "${(season.appearances * 0.30).round()}",
        "wr": "${(winRate - 3).clamp(0, 100)}%",
        "rating": (season.rating - 0.1).toStringAsFixed(1),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("COMPETITION STATS", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text("League",
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("MP",
                          textAlign: TextAlign.center,
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("WR",
                          textAlign: TextAlign.center,
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("Rating",
                          textAlign: TextAlign.right,
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Stat rows
              ...competitions.asMap().entries.map((entry) {
                final comp = entry.value;
                final isLast = entry.key == competitions.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(comp["name"]!, style: Heading5.style),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(comp["mp"]!,
                                textAlign: TextAlign.center,
                                style: Heading5.style),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(comp["wr"]!,
                                textAlign: TextAlign.center,
                                style: Heading5.style),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3D3D3D),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(comp["rating"]!,
                                    style: Heading5.style),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(color: Colors.white12, height: 1),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchSummaryBlock() {
    final matches = playerRepository.recentMatchesFor(player.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("MATCHES", style: Body2_b.style),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        // Each match is its own card (shared with the Matches tab).
        ...matches.map((match) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlayerMatchCard(
              result: match.result,
              score: match.score,
              competition: match.competition,
              againstLogo: match.opponentLogoAsset,
              stats: [
                {'label': 'Goal', 'value': '${match.goals}'},
                {'label': 'Assist', 'value': '${match.assists}'},
                {'label': 'Pass', 'value': '${match.passes}'},
              ],
              rating: match.rating.toStringAsFixed(1),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildClubHistoryBlock() {
    final history = player.clubHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("CLUB HISTORY", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: history.map((club) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Team logo
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: club.logoAsset == null
                                ? const Icon(
                                    Icons.shield_outlined,
                                    color: Colors.white54,
                                  )
                                : Image.asset(
                                    club.logoAsset!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Club name
                        Expanded(
                          child: Text(club.club, style: Heading5.style),
                        ),
                        // Year
                        Text(
                          club.seasonLabel,
                          style: Body1.style,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class PlayerBioStatsBlock extends StatelessWidget {
  final Player player;

  const PlayerBioStatsBlock({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final birthDate = DateTime.parse(player.dateOfBirth);
    final now = DateTime.now();
    final age = now.year -
        birthDate.year -
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
            ? 1
            : 0);
    final stats = [
      {"label": "Height", "value": "${player.heightCm}cm", "icon": null},
      {"label": "Weight", "value": "${player.weightKg}kg", "icon": null},
      {"label": "Age", "value": "$age yrs", "icon": null},
      {"label": "Form", "value": player.form, "icon": "refresh"},
      {"label": "Market Value", "value": player.marketValue, "icon": null},
      {"label": "Squad Role", "value": player.squadRole, "icon": null},
      {"label": "Preferred Foot", "value": player.preferredFoot, "icon": null},
      {
        "label": "Cost-Effectiveness",
        "value": "Very Good",
        "icon": "refresh",
        "infoOnLabel": true
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minCellWidth = 110.0;
          final columnCount =
              (constraints.maxWidth / minCellWidth).floor().clamp(1, 3);
          final rows = <List<Map<String, dynamic>>>[];
          for (var i = 0; i < stats.length; i += columnCount) {
            rows.add(stats.sublist(
              i,
              (i + columnCount).clamp(0, stats.length),
            ));
          }

          return Column(
            children: rows.asMap().entries.map((entry) {
              final rowIndex = entry.key;
              final row = entry.value;

              return Column(
                children: [
                  if (rowIndex != 0)
                    const Divider(color: Colors.white12, height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: row.asMap().entries.map((cellEntry) {
                      final cellIndex = cellEntry.key;
                      final stat = cellEntry.value;
                      final isLast = cellIndex == row.length - 1;

                      return Expanded(
                        flex: columnCount == 3 &&
                                stat["label"] == "Cost-Effectiveness"
                            ? 2
                            : 1,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          stat["label"] as String,
                                          style: Body2.style
                                              .copyWith(color: Colors.white54),
                                        ),
                                      ),
                                      if (stat["infoOnLabel"] == true)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(Icons.info_outline,
                                              size: 14, color: Colors.white54),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          stat["value"] as String,
                                          style: Heading5.style,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (stat["icon"] == "refresh")
                                        const Padding(
                                          padding: EdgeInsets.only(left: 6),
                                          child: Icon(Icons.refresh,
                                              size: 16, color: Colors.white70),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white12,
                                margin: const EdgeInsets.only(right: 12),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
