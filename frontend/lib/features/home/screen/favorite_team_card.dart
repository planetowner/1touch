part of 'home_screen_features.dart';

class FavoriteTeamCard extends StatelessWidget {
  final TeamOverview team;

  const FavoriteTeamCard({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final match = team.liveMatch ?? team.nextMatch;
    final competitionContext = teamCompetitionContextResolver.resolve(team.id);
    final leagueName = competitionNameLabel(
        context,
        competitionContext?.competitionId,
        competitionContext?.competitionName ?? '');
    final standingPosition = team.standing?['position'];
    final rank = standingPosition is int
        ? standingPosition
        : competitionContext?.currentPosition;
    final rankDelta = team.standing?['rank_delta'] as int?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Material(
        color: appColors.cardBackground,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          key: const ValueKey('home-favorite-team-surface'),
          width: 375,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: appColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TEAM HEADER
              GestureDetector(
                onTap: isTeamPageSupported(team.id)
                    ? () => openTeamPage(context, team.id)
                    : null,
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        team.imagePath,
                        width: 50,
                        height: 50,
                        errorBuilder: (_, __, ___) =>
                            teamLogoFallback(team.id, size: 50),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamNameLabel(context, team.id, team.name),
                            // '1. Fußballclub Heidenheim 1846 e.V',
                            style: Heading3.style,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "$leagueName ${rank != null ? ordinal(rank, locale: Localizations.localeOf(context)) : '-'}",
                                  key: const ValueKey('home-team-standing'),
                                  style: Body2.style.copyWith(height: 1.3),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (rankDelta != null && rankDelta != 0)
                                _StandingMovement(delta: rankDelta),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // NEXT MATCH (from API)
              if (match != null)
                GestureDetector(
                    onTap: () {
                      final status = match.status.name;
                      context.push(
                        '/match/${match.fixtureId}?status=$status',
                        extra: match,
                      );
                    },
                    child: MatchCard(
                      match: match,
                      leagueName: competitionRepository
                          .findById(match.competitionId)
                          ?.name,
                    )),

              // LAST MATCH
              if (team.lastMatch != null)
                GestureDetector(
                  onTap: () {
                    final last = team.lastMatch!;
                    final status = last.status.name;
                    context.push(
                      '/match/${last.fixtureId}?status=$status',
                      extra: last,
                    );
                  },
                  child: () {
                    final last = team.lastMatch!;
                    final home = fixtureHomeTeam(last, teamRepository);
                    final away = fixtureAwayTeam(last, teamRepository);
                    final kickoff = last.kickoff;
                    return MatchCard2(
                      date: relativeDateLabel(kickoff,
                          locale: Localizations.localeOf(context)),
                      venue: '',
                      team1shortname: home.shortCode ??
                          teamNameLabel(context, home.teamId, home.name),
                      team1Logo: home.imagePath ?? '',
                      team1Id: home.teamId,
                      team2shortname: away.shortCode ??
                          teamNameLabel(context, away.teamId, away.name),
                      team2Logo: away.imagePath ?? '',
                      team2Id: away.teamId,
                      homeScore: last.homeScore ?? 0,
                      awayScore: last.awayScore ?? 0,
                    );
                  }(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingMovement extends StatelessWidget {
  const _StandingMovement({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final rising = delta > 0;
    return Row(
      key: const ValueKey('home-team-rank-movement'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.flip(
          flipY: !rising,
          child: SvgPicture.asset(
            rising
                ? 'assets/standings/rank_up.svg'
                : 'assets/standings/rank_down.svg',
            width: 24,
            height: 24,
          ),
        ),
        Text('${delta.abs()}', style: Eyebrow.style.copyWith(height: 1.3)),
      ],
    );
  }
}
