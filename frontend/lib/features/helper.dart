import 'package:flutter/material.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import "package:onetouch/core/style.dart";
import "package:onetouch/core/stylesheet.dart";
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/l10n/app_localizations.dart';

// Maps a team's id to its local crest file in TeamLogos/, used as the
// fallback when the network image fails to load. Filenames don't follow a
// clean rule from `name`/`shortCode` (mixed casing, missing spaces, accents),
// so this is hand-built from what's actually sitting in the asset folder.
// Keyed by the real Sportmonks team_id. Only teams whose crest is actually in
// the asset folder are listed; every other team (most of the 96) has no local
// crest and falls back to a generic shield icon via `teamLogoAsset` returning
// null.
const _teamLogoFiles = <int, String>{
  // Premier League
  9: 'ManCity', 14: 'ManUtd', 8: 'Liverpool', 19: 'Arsenal', 18: 'Chelsea',
  6: 'Tottenham', 20: 'NewCastle', 15: 'AstonVilla',
  // La Liga
  83: 'Barcelona', 7980: 'AtleticoMadrid', 3468: 'RealMadrid', 676: 'Sevilla',
  3477: 'Villarreal', 214: 'Valencia', 13258: 'AthleticClub', 485: 'RealBetis',
  594: 'Real Sociedad', 459: 'Osasuna', 645: 'Mallorca', 106: 'Getafe',
  36: 'CeltaVigo', 377: 'RayoVallecano', 231: 'Girona',
  2975: 'DeportivoAlavés', 528: 'Espanyol',
  // Serie A
  2930: 'InterMilan', 113: 'AcMilan', 625: 'Juventus', 597: 'Napoli',
  43: 'Lazio', 37: 'AsRoma',
  // Bundesliga
  503: 'BayernMunich', 68: 'BorussiaDortmund', 3321: 'BayerLeverkusen',
  277: 'RbLeipzig', 510: 'Wolfsburg', 3319: 'Stuttgart',
  // Ligue 1
  591: 'ParisSaintGermain', 79: 'OlympiqueLyon', 44: 'Marseille',
  6789: 'AsMonaco', 450: 'Nice', 690: 'Lille',
};

/// Local crest asset for [teamId] to use when the network image fails to
/// load. Returns null if there's no matching asset for this team.
String? teamLogoAsset(int teamId) {
  final file = _teamLogoFiles[teamId];
  return file == null ? null : 'TeamLogos/$file.png';
}

/// Image.network errorBuilder fallback: the team's local crest if we have
/// one, otherwise a generic shield icon rather than guessing wrong.
Widget teamLogoFallback(int teamId, {double size = 32}) {
  final asset = teamLogoAsset(teamId);
  if (asset == null) {
    return Builder(
      builder: (context) => Icon(
        Icons.shield,
        color: AppColors.of(context).mutedForeground,
        size: size,
      ),
    );
  }
  return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
}

// Local crests for the Big 5 domestic leagues, used as the errorBuilder
// fallback when a league's network logo fails to load. No local asset
// exists for UCL/Europa/cups, so those fall back to a generic icon.
const _competitionLogoFiles = <int, String>{
  8: 'assets/epl.png',
  564: 'assets/laliga.png',
  82: 'assets/bundesliga.png',
  384: 'assets/seriea.png',
  301: 'assets/league1.png',
};

Widget competitionLogoFallback(int competitionId, {double size = 24}) {
  final asset = _competitionLogoFiles[competitionId];
  if (asset == null) {
    return Builder(
      builder: (context) => Icon(
        Icons.shield,
        color: AppColors.of(context).mutedForeground,
        size: size,
      ),
    );
  }
  return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
}

//
// UTILITIES & HELPERS
//

String leaguePositionLabel(
    BuildContext context, String leagueName, int? position) {
  final rank = position == null
      ? '-'
      : ordinal(position, locale: Localizations.localeOf(context));
  return '$leagueName $rank';
}

String ordinal(int number, {Locale locale = const Locale('en')}) {
  if (locale.languageCode != 'en') {
    return translateMessage(locale, '{rank} place', {'rank': number});
  }
  if (number >= 11 && number <= 13) return '${number}th';
  switch (number % 10) {
    case 1:
      return '${number}st';
    case 2:
      return '${number}nd';
    case 3:
      return '${number}rd';
    default:
      return '${number}th';
  }
}

String determineMatchStatus(DateTime matchDateTime) {
  final now = DateTime.now();
  final matchEndTime = matchDateTime.add(const Duration(hours: 2));

  if (now.isAfter(matchEndTime)) {
    return 'past';
  } else if (now.isAfter(matchDateTime) && now.isBefore(matchEndTime)) {
    return 'live';
  } else {
    return 'upcoming';
  }
}

//
// MAIN WIDGETS (MatchCards)
//

class MatchCard extends StatelessWidget {
  final Fixture? match;
  final String? leagueName;
  final Color? backgroundColor;

  const MatchCard({
    super.key,
    required this.match,
    this.leagueName,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (match == null) return const SizedBox.shrink();

    final homeTeam = fixtureHomeTeam(match!, teamRepository);
    final awayTeam = fixtureAwayTeam(match!, teamRepository);

    return Container(
      key: const ValueKey('match-card-surface'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.of(context).subtleBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match!.status == FixtureStatus.live
                ? tr(context, 'LIVE MATCH')
                : tr(context, 'NEXT MATCH'),
            style: Body1_b.style,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 300;
              final infoGap = compact ? 0.0 : 8.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: compact ? 72 : 81,
                    child: _TeamDisplay(
                      teamId: homeTeam.teamId,
                      teamName: homeTeam.displayName,
                      teamLogo: homeTeam.imagePath ?? '',
                      logoSize: 72,
                      logoKey: const ValueKey('next-match-home-logo'),
                    ),
                  ),
                  SizedBox(width: infoGap),
                  Expanded(
                    child: _MatchInfo(
                      match: match,
                      leagueName: leagueName == null
                          ? null
                          : competitionNameLabel(
                              context, match!.competitionId, leagueName!),
                    ),
                  ),
                  SizedBox(width: infoGap),
                  SizedBox(
                    width: compact ? 72 : 76,
                    child: _TeamDisplay(
                      teamId: awayTeam.teamId,
                      teamName: awayTeam.displayName,
                      teamLogo: awayTeam.imagePath ?? '',
                      logoSize: 72,
                      logoKey: const ValueKey('next-match-away-logo'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class MatchCard2 extends StatelessWidget {
  final String date,
      venue,
      team1shortname,
      team1Logo,
      team2shortname,
      team2Logo;
  final int team1Id;
  final int team2Id;
  final int homeScore;
  final int awayScore;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? dateTextStyle;

  const MatchCard2({
    super.key,
    required this.date,
    required this.venue,
    required this.team1shortname,
    required this.team1Logo,
    required this.team1Id,
    required this.team2shortname,
    required this.team2Logo,
    required this.team2Id,
    required this.homeScore,
    required this.awayScore,
    this.backgroundColor,
    this.contentPadding,
    this.dateTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Example scores

    return Container(
      key: const ValueKey('last-match-card-surface'),
      padding:
          contentPadding ?? const EdgeInsets.only(left: 16, right: 16, top: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.of(context).cardBackground,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'LAST MATCH'),
            key: const ValueKey('last-match-title'),
            style: Body1_b.style,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final veryCompact = constraints.maxWidth < 270;
              const teamWidth = 48.0;
              const teamScoreGap = 16.0;
              final sectionSpacing = veryCompact
                  ? 0.0
                  : constraints.maxWidth < 300
                      ? 0.0
                      : 30.0;
              final matchRow = Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: sectionSpacing,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: teamWidth,
                        child: _TeamDisplay2(
                          teamId: team1Id,
                          teamName: team1shortname,
                          teamLogo: team1Logo,
                          logoSize: teamWidth,
                          logoKey: const ValueKey('last-match-home-logo'),
                        ),
                      ),
                      SizedBox(width: teamScoreGap),
                      _ScoreBoard(
                        key: const ValueKey('last-match-home-score'),
                        score: homeScore,
                        isDimmed: homeScore < awayScore,
                      ),
                    ],
                  ),
                  Expanded(
                    child: _MatchInfo2(
                      key: const ValueKey('last-match-date-time'),
                      date: date,
                      venue: venue,
                      textStyle: dateTextStyle ?? Body2.style,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScoreBoard(
                        key: const ValueKey('last-match-away-score'),
                        score: awayScore,
                        isDimmed: awayScore < homeScore,
                      ),
                      SizedBox(width: teamScoreGap),
                      SizedBox(
                        width: teamWidth,
                        child: _TeamDisplay2(
                          teamId: team2Id,
                          teamName: team2shortname,
                          teamLogo: team2Logo,
                          logoSize: teamWidth,
                          logoKey: const ValueKey('last-match-away-logo'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
              if (!veryCompact) return matchRow;
              return SizedBox(
                height: 92,
                child: OverflowBox(
                  alignment: Alignment.center,
                  minWidth: constraints.maxWidth + 16,
                  maxWidth: constraints.maxWidth + 16,
                  child: matchRow,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SearchMatchCard extends StatelessWidget {
  final String homeTeam;
  final String homeLogo;
  final String awayTeam;
  final String awayLogo;
  final String date;
  final String time;

  const SearchMatchCard({
    super.key,
    required this.homeTeam,
    required this.homeLogo,
    required this.awayTeam,
    required this.awayLogo,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    const score1 = 3;
    const score2 = 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // HOME TEAM (Left)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: 45,
                  height: 45,
                  child: Image.asset(
                    homeLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (c, o, s) =>
                        const Icon(Icons.shield, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  homeTeam,
                  style: Body2.style.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // CENTER INFO (# Date/Time #)
          Row(
            children: [
              // Reusing the internal _ScoreBoard with "#"
              const _ScoreBoard(
                score: score1,
                isDimmed: false,
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const _ScoreBoard(
                score: score2,
                isDimmed: true,
              ),
            ],
          ),

          // AWAY TEAM (Right)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: 45,
                  height: 45,
                  child: Image.asset(
                    awayLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (c, o, s) =>
                        const Icon(Icons.shield, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  awayTeam,
                  style: Body2.style.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//
// INTERNAL WIDGET COMPONENTS
//

class _TeamDisplay extends StatelessWidget {
  final int teamId;
  final String teamName, teamLogo;
  final double logoSize;
  final Key? logoKey;

  const _TeamDisplay({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.logoSize,
    this.logoKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: logoKey,
          width: logoSize,
          height: logoSize,
          child: teamLogo.isEmpty
              ? teamLogoFallback(teamId, size: logoSize)
              : Image.network(
                  teamLogo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      teamLogoFallback(teamId, size: logoSize),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          teamNameLabel(context, teamId, teamName, short: true),
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: Body1.style,
        ),
      ],
    );
  }
}

class _TeamDisplay2 extends StatelessWidget {
  final int teamId;
  final String teamName, teamLogo;
  final double logoSize;
  final Key? logoKey;

  const _TeamDisplay2({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.logoSize,
    this.logoKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: logoKey,
          width: logoSize,
          height: logoSize,
          child: teamLogo.isEmpty
              ? teamLogoFallback(teamId, size: logoSize)
              : Image.network(
                  teamLogo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      teamLogoFallback(teamId, size: logoSize),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          teamName,
          textAlign: TextAlign.center,
          style: Eyebrow.style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MatchInfo extends StatelessWidget {
  final Fixture? match;
  final String? leagueName;

  const _MatchInfo({
    required this.match,
    this.leagueName,
  });

  @override
  Widget build(BuildContext context) {
    final roundLabel =
        fixtureRoundLabel(match, locale: Localizations.localeOf(context));
    final competitionAndRound =
        fixtureCompetitionLabel(context, match, competitionName: leagueName) ??
            [
              leagueName ?? 'League',
              if (roundLabel != null) roundLabel,
            ].join('  ');

    return Column(
      children: [
        FixtureDateTime(
          label: fixtureDateLabel(match!.kickoff,
              locale: Localizations.localeOf(context)),
        ),
        const SizedBox(height: 8),
        Container(
          width: 24,
          height: 1,
          color: AppColors.of(context).divider,
        ),
        const SizedBox(height: 8),
        Text(
          competitionAndRound,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Body2.style,
        ),
        const SizedBox(height: 4),
        // Text('Venue ID ${match?.venueId}', style: .style),
      ],
    );
  }
}

class _MatchInfo2 extends StatelessWidget {
  final String date, venue;
  final TextStyle textStyle;

  const _MatchInfo2({
    super.key,
    required this.date,
    required this.venue,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FixtureDateTime(
          label: date,
          textStyle: textStyle,
        ),
      ],
    );
  }
}

// 홈과 일정에서 날짜·시간을 각각 한 줄로 맞춰요.
class FixtureDateTime extends StatelessWidget {
  const FixtureDateTime({
    super.key,
    required this.label,
    this.textStyle,
  });

  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in label.split('\n'))
          Text(
            line,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textStyle ?? Body2.style,
          ),
      ],
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  final int score;
  final bool isDimmed;

  const _ScoreBoard({
    super.key,
    required this.score,
    required this.isDimmed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: const Color(0xFF090A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          Opacity(
            opacity: isDimmed ? 0.5 : 1.0,
            child: Text(
              score.toString(),
              textAlign: TextAlign.center,
              style: Heading3.style.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// just in case

// class MatchCard3 extends StatelessWidget {
//   final String date, venue, team1Name, team1Logo, team2Name, team2Logo;
//
//   const MatchCard3({
//     super.key,
//     required this.date,
//     required this.venue,
//     required this.team1Name,
//     required this.team1Logo,
//     required this.team2Name,
//     required this.team2Logo,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: const BoxDecoration(
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//           bottomLeft: Radius.circular(0),
//           bottomRight: Radius.circular(0),
//         ),
//         color: Color(0xFF3D3D3D),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('NEXT MATCH', style: Body1_b.style),
//           const SizedBox(height: 16),
//           LayoutBuilder(
//             builder: (context, constraints) {
//               return Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: _TeamDisplay(teamName: team1Name, teamLogo: team1Logo),
//                   ),
//                   const SizedBox(width: 24),
//                   _MatchInfo(match: , leagueName: ,), // Commented out in original
//                   const SizedBox(width: 24),
//                   Expanded(
//                     child: _TeamDisplay(teamName: team2Name, teamLogo: team2Logo),
//                   ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
