part of 'match_info_features.dart';

class MatchScoreHeader extends StatelessWidget {
  final String homeLogoAsset;
  final String awayLogoAsset;
  final int homeTeamId;
  final int awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final String homeScore;
  final String awayScore;
  final String statusLabel; // e.g. "Final" or "Live"
  final String? roundLabel; // e.g. "R16", "RO 33"
  final String? venueLabel;

  const MatchScoreHeader({
    super.key,
    required this.homeLogoAsset,
    required this.awayLogoAsset,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeScore,
    required this.awayScore,
    required this.statusLabel,
    required this.roundLabel,
    this.venueLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Dim whichever side lost — only when both scores actually parse (e.g.
    // not the '#' placeholder used before a fixture has a result yet).
    final home = int.tryParse(homeScore);
    final away = int.tryParse(awayScore);
    final homeDimmed = home != null && away != null && home < away;
    final awayDimmed = home != null && away != null && away < home;
    final round = roundLabel?.trim();
    final visibleRoundLabel = round != null && int.tryParse(round) != null
        ? 'Round $round'
        : round;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final gap = compact ? 8.0 : 20.0;
        final logoSize = compact ? 52.0 : 72.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TeamBlock(
                teamId: homeTeamId,
                logoAsset: homeLogoAsset,
                name: homeTeamName,
                logoSize: logoSize,
              ),
            ),
            SizedBox(width: gap),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (visibleRoundLabel?.isNotEmpty ?? false) ...[
                  Text(visibleRoundLabel!, style: Body2.style),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    _ScoreBox(
                      score: homeScore,
                      isDimmed: homeDimmed,
                      compact: compact,
                    ),
                    const SizedBox(width: 8),
                    _ScoreBox(
                      score: awayScore,
                      isDimmed: awayDimmed,
                      compact: compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(statusLabel, style: Body2_b.style),
                if (venueLabel?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: compact ? 92 : 120,
                    child: Text(
                      venueLabel!.trim(),
                      style: Eyebrow.style,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(width: gap),
            Expanded(
              child: _TeamBlock(
                teamId: awayTeamId,
                logoAsset: awayLogoAsset,
                name: awayTeamName,
                logoSize: logoSize,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final int teamId;
  final String logoAsset;
  final String name;
  final double logoSize;
  const _TeamBlock(
      {required this.teamId,
      required this.logoAsset,
      required this.name,
      required this.logoSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          // The match screen is pushed on the root navigator (see
          // parentNavigatorKey on '/match/:matchId' in main.dart), but
          // '/team/:id' lives inside the bottom-nav shell's own navigator —
          // push() would land there invisibly, behind this screen. go()
          // replaces the location so the shell actually surfaces.
          onTap: isTeamPageSupported(teamId)
              ? () => openTeamPage(context, teamId)
              : null,
          child: Image.network(
            logoAsset,
            width: logoSize,
            height: logoSize,
            errorBuilder: (_, __, ___) =>
                teamLogoFallback(teamId, size: logoSize),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: Body1.style,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String score;
  final bool isDimmed;
  final bool compact;
  const _ScoreBox({
    required this.score,
    this.isDimmed = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkGrey : AppPalette.lightGreyBox,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        score,
        style: Heading1.style.copyWith(
          color: isDimmed ? AppColors.of(context).mutedForeground : foreground,
        ),
      ),
    );
  }
}
