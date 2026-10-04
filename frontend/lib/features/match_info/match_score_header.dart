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
  final Widget status;
  // 공통 표시 함수에서 번역한 문구를 그대로 받아요.
  final String? roundLabel;

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
    required this.status,
    required this.roundLabel,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    // Dim whichever side lost — only when both scores actually parse (e.g.
    // not the '#' placeholder used before a fixture has a result yet).
    final home = int.tryParse(homeScore);
    final away = int.tryParse(awayScore);
    final homeDimmed = home != null && away != null && home < away;
    final awayDimmed = home != null && away != null && away < home;

    // Figma의 양쪽 팀 슬롯을 고정해 제목 길이가 로고·팀명 위치에 영향을 주지 않아요.
    const homeWidth = 81.0;
    const awayWidth = 76.0;
    return LayoutBuilder(
      builder: (context, _) => Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                key: const ValueKey('match-score-home-team'),
                width: homeWidth,
                child: _TeamBlock(
                  teamId: homeTeamId,
                  logoAsset: homeLogoAsset,
                  name: homeTeamName,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 제목 18px와 점수 위 여백 16px는 제목 유무와 관계없이 유지해요.
                    const SizedBox(height: 34),
                    SizedBox(
                      height: 65,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          key: const ValueKey('match-score-values'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ScoreBox(
                              key: const ValueKey('match-home-score-box'),
                              score: homeScore,
                              isDimmed: homeDimmed,
                            ),
                            const SizedBox(width: 8),
                            _ScoreBox(
                              key: const ValueKey('match-away-score-box'),
                              score: awayScore,
                              isDimmed: awayDimmed,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DefaultTextStyle(
                      style: Body2.style.copyWith(
                        height: 1.3,
                        color: foreground,
                      ),
                      textAlign: TextAlign.center,
                      child: status,
                    ),
                  ],
                ),
              ),
              SizedBox(
                key: const ValueKey('match-score-away-team'),
                width: awayWidth,
                child: _TeamBlock(
                  teamId: awayTeamId,
                  logoAsset: awayLogoAsset,
                  name: awayTeamName,
                ),
              ),
            ],
          ),
          if (roundLabel?.isNotEmpty ?? false)
            Positioned(
              top: 0,
              // 양쪽 슬롯 폭이 달라 생기는 점수 중심에 제목도 맞춰요.
              left: homeWidth - awayWidth,
              right: 0,
              child: Text(
                roundLabel!,
                style: Body2.style.copyWith(height: 1.3),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final int teamId;
  final String logoAsset;
  final String name;
  const _TeamBlock(
      {required this.teamId, required this.logoAsset, required this.name});

  @override
  Widget build(BuildContext context) {
    const logoSize = 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        GestureDetector(
          // A team opened from this root-level match keeps the match beneath
          // it, allowing back navigation to return to this fixture.
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
        // Figma처럼 이름은 로고 중심에 맞추고, 글자 폭으로 팀 슬롯을 넓히지 않아요.
        OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          fit: OverflowBoxFit.deferToChild,
          child: Text(
            name,
            style: Body1.style.copyWith(height: 1.3),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String score;
  final bool isDimmed;
  const _ScoreBox({
    super.key,
    required this.score,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 61,
      height: 65,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkGrey : const Color(0x1A0A0A0A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          score,
          style: Heading1.latinStyle.copyWith(
            color: isDimmed ? foreground.withValues(alpha: 0.5) : foreground,
          ),
        ),
      ),
    );
  }
}
