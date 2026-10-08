import 'dart:async';

import 'package:clock/clock.dart' as time;
import 'package:flutter/material.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import "package:onetouch/core/style.dart";
import "package:onetouch/core/stylesheet.dart";
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_clock.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/match_status_labels.dart';
import 'package:onetouch/features/match_info/live_match_motion.dart';
import 'package:onetouch/features/competition/competition_label.dart';
import 'package:onetouch/core/overflow_scrolling_text.dart';

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

//
// MAIN WIDGETS (MatchCards)
//

class MatchCard extends StatelessWidget {
  final Fixture? match;
  final String? leagueName;
  final Color? backgroundColor;
  final FixtureClock? clock;

  const MatchCard({
    super.key,
    required this.match,
    this.leagueName,
    this.backgroundColor,
    this.clock,
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
          if (match!.status == FixtureStatus.live)
            Row(
              children: [
                LivePulseDot(color: Body1_b.style.color),
                const SizedBox(width: 6),
                Text(tr(context, 'LIVE MATCH'), style: Body1_b.style),
              ],
            )
          else
            Text(trUpper(context, 'Next match'), style: Body1_b.style),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 300;
              // TODO: 좁은 화면용 디자인을 확인할 때까지 64px을 유지해요.
              // 확인 결과에 따라 크기를 바꾸거나 64px로 확정해요.
              final logoSize = compact ? 64.0 : 72.0;
              final infoGap = compact ? 0.0 : 8.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: compact ? logoSize : 81,
                    child: _TeamDisplay(
                      teamId: homeTeam.teamId,
                      teamName: teamNameLabel(
                          context, homeTeam.teamId, homeTeam.displayName,
                          short: true),
                      nameStyle: Body1.style,
                      teamLogo: homeTeam.imagePath ?? '',
                      logoSize: logoSize,
                      logoKey: const ValueKey('next-match-home-logo'),
                    ),
                  ),
                  SizedBox(width: infoGap),
                  Expanded(
                    child: _MatchInfo(
                      match: match,
                      clock: clock,
                      leagueName: leagueName == null
                          ? null
                          : competitionNameLabel(
                              context, match!.competitionId, leagueName!),
                    ),
                  ),
                  SizedBox(width: infoGap),
                  SizedBox(
                    width: compact ? logoSize : 76,
                    child: _TeamDisplay(
                      teamId: awayTeam.teamId,
                      teamName: teamNameLabel(
                          context, awayTeam.teamId, awayTeam.displayName,
                          short: true),
                      nameStyle: Body1.style,
                      teamLogo: awayTeam.imagePath ?? '',
                      logoSize: logoSize,
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
  final int? homeScore;
  final int? awayScore;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? dateTextStyle;
  final bool showTitle;
  final BorderRadiusGeometry? borderRadius;
  final Key surfaceKey;

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
    this.showTitle = true,
    this.borderRadius,
    this.surfaceKey = const ValueKey('last-match-card-surface'),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: surfaceKey,
      padding:
          contentPadding ?? const EdgeInsets.only(left: 16, right: 16, top: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.of(context).cardBackground,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              tr(context, 'LAST MATCH'),
              key: const ValueKey('last-match-title'),
              style: Body1_b.style,
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              const teamWidth = 48.0;
              final resolvedDateStyle = dateTextStyle ?? Body2.style;
              final homeDimmed = homeScore != null &&
                  awayScore != null &&
                  homeScore! < awayScore!;
              final awayDimmed = homeScore != null &&
                  awayScore != null &&
                  awayScore! < homeScore!;

              double textWidth(String value, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: value, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  locale: Localizations.maybeLocaleOf(context),
                  maxLines: 1,
                )..layout();
                final width = painter.width;
                painter.dispose();
                return width;
              }

              final scoreStyle =
                  Heading3.latinStyle.copyWith(color: Colors.white);
              final homeScoreWidth =
                  textWidth(homeScore?.toString() ?? '-', scoreStyle) + 24;
              final awayScoreWidth =
                  textWidth(awayScore?.toString() ?? '-', scoreStyle) + 24;
              final fixedContentWidth =
                  teamWidth * 2 + homeScoreWidth + awayScoreWidth;
              final dateWidth = date
                  .split('\n')
                  .map((line) => textWidth(line, resolvedDateStyle))
                  .fold(
                      0.0, (widest, width) => width > widest ? width : widest);
              // 로고·점수·날짜 사이 네 간격을 남는 폭에 맞춰 균등하게 나눠요.
              // 날짜가 더 길면 글자 크기 대신 가운데 영역만 스크롤해요.
              final gap =
                  ((constraints.maxWidth - fixedContentWidth - dateWidth - 8) /
                          4)
                      .clamp(4.0, 16.0)
                      .toDouble();
              final matchRow = Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: teamWidth,
                        child: _TeamDisplay(
                          teamId: team1Id,
                          teamName: team1shortname,
                          nameStyle: Eyebrow.style,
                          nameMaxLines: 2,
                          teamLogo: team1Logo,
                          logoSize: teamWidth,
                          logoKey: const ValueKey('last-match-home-logo'),
                        ),
                      ),
                      SizedBox(width: gap),
                      _ScoreBoard(
                        key: const ValueKey('last-match-home-score'),
                        score: homeScore,
                        isDimmed: homeDimmed,
                      ),
                    ],
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _MatchInfo2(
                      key: const ValueKey('last-match-date-time'),
                      date: date,
                      venue: venue,
                      textStyle: resolvedDateStyle,
                    ),
                  ),
                  SizedBox(width: gap),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScoreBoard(
                        key: const ValueKey('last-match-away-score'),
                        score: awayScore,
                        isDimmed: awayDimmed,
                      ),
                      SizedBox(width: gap),
                      SizedBox(
                        width: teamWidth,
                        child: _TeamDisplay(
                          teamId: team2Id,
                          teamName: team2shortname,
                          nameStyle: Eyebrow.style,
                          nameMaxLines: 2,
                          teamLogo: team2Logo,
                          logoSize: teamWidth,
                          logoKey: const ValueKey('last-match-away-logo'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
              return matchRow;
            },
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
  final TextStyle nameStyle;
  final int nameMaxLines;

  const _TeamDisplay({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.logoSize,
    this.logoKey,
    required this.nameStyle,
    this.nameMaxLines = 1,
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
          maxLines: nameMaxLines,
          softWrap: nameMaxLines == 1 ? false : null,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
      ],
    );
  }
}

class _MatchInfo extends StatelessWidget {
  final Fixture? match;
  final String? leagueName;
  final FixtureClock? clock;

  const _MatchInfo({
    required this.match,
    this.leagueName,
    this.clock,
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

    if (match!.status == FixtureStatus.live) {
      return _LiveMatchInfo(
        match: match!,
        clock: clock,
        competitionAndRound: competitionAndRound,
      );
    }

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
        CompetitionLabel(
          competitionId: match!.competitionId,
          label: competitionAndRound,
          style: Body2.style,
          gap: 4,
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _LiveMatchInfo extends StatelessWidget {
  const _LiveMatchInfo({
    required this.match,
    required this.clock,
    required this.competitionAndRound,
  });

  final Fixture match;
  final FixtureClock? clock;
  final String competitionAndRound;

  @override
  Widget build(BuildContext context) {
    final homeScore = match.homeScore;
    final awayScore = match.awayScore;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          key: const ValueKey('live-match-score-row'),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LiveScoreBoard(
              key: const ValueKey('live-match-home-score'),
              score: homeScore,
              isDimmed: homeScore != null &&
                  awayScore != null &&
                  homeScore < awayScore,
            ),
            const SizedBox(width: 8),
            _LiveScoreBoard(
              key: const ValueKey('live-match-away-score'),
              score: awayScore,
              isDimmed: homeScore != null &&
                  awayScore != null &&
                  awayScore < homeScore,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _LiveMatchClockLabel(match: match, clock: clock),
        const SizedBox(height: 8),
        LiveTrimLine(color: AppColors.of(context).divider),
        const SizedBox(height: 8),
        CompetitionLabel(
          competitionId: match.competitionId,
          label: competitionAndRound,
          style: Body2.style,
          gap: 4,
        ),
      ],
    );
  }
}

class _LiveScoreBoard extends StatelessWidget {
  const _LiveScoreBoard({
    super.key,
    required this.score,
    required this.isDimmed,
  });

  final int? score;
  final bool isDimmed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkGrey : AppPalette.lightModeDarkGrey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Opacity(
        opacity: isDimmed ? 0.5 : 1,
        child: Text(
          score?.toString() ?? '-',
          textAlign: TextAlign.center,
          style: Heading2.latinStyle.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _LiveMatchClockLabel extends StatefulWidget {
  const _LiveMatchClockLabel({required this.match, required this.clock});

  final Fixture match;
  final FixtureClock? clock;

  @override
  State<_LiveMatchClockLabel> createState() => _LiveMatchClockLabelState();
}

class _LiveMatchClockLabelState extends State<_LiveMatchClockLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _LiveMatchClockLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock || oldWidget.match != widget.match) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!(widget.clock?.isRunningAt(time.clock.now()) ?? false)) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      if (!(widget.clock?.isRunningAt(time.clock.now()) ?? false)) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.clock?.totalSecondsAt(time.clock.now());
    final label = totalSeconds == null
        ? matchStatusLabel(
            widget.match,
            clock: widget.clock,
            now: time.clock.now(),
            locale: Localizations.localeOf(context),
          )
        : '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:'
            '${(totalSeconds % 60).toString().padLeft(2, '0')}';
    return Text(
      label,
      key: const ValueKey('live-match-clock'),
      textAlign: TextAlign.center,
      style: Body2.style,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in date.split('\n'))
          OverflowScrollingText(
            text: line,
            style: textStyle,
            alignment: Alignment.center,
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
    this.overflow = TextOverflow.ellipsis,
    this.maxLines = 1,
    this.softWrap = false,
  });

  final String label;
  final TextStyle? textStyle;
  final TextOverflow overflow;
  final int maxLines;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in label.split('\n'))
          Text(
            line,
            maxLines: maxLines,
            softWrap: softWrap,
            overflow: overflow,
            textAlign: TextAlign.center,
            style: textStyle ?? Body2.style,
          ),
      ],
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  final int? score;
  final bool isDimmed;

  const _ScoreBoard({
    super.key,
    required this.score,
    required this.isDimmed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: isDark ? AppPalette.black : AppPalette.lightModeDarkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          Opacity(
            opacity: isDark && isDimmed ? 0.5 : 1,
            child: Text(
              score?.toString() ?? '-',
              textAlign: TextAlign.center,
              style: Heading3.latinStyle.copyWith(
                color: !isDark && isDimmed
                    ? foreground.withValues(alpha: 0.5)
                    : foreground,
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
