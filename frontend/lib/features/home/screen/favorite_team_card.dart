part of 'home_screen_features.dart';

class FavoriteTeamCard extends StatelessWidget {
  final TeamOverview team;
  final FixtureClock? liveMatchClock;

  const FavoriteTeamCard({
    super.key,
    required this.team,
    this.liveMatchClock,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final match = team.liveMatch ?? team.nextMatch;
    final competitionContext = teamCompetitionContextResolver.resolve(team.id);
    final leagueName = competitionNameLabel(
        context,
        competitionContext?.competitionId,
        competitionContext?.competitionName ?? '');
    final rank = team.standing?.position ?? competitionContext?.currentPosition;
    final rankDelta = team.standing?.rankDelta;

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
                behavior: HitTestBehavior.opaque,
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
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          TeamStandingLabel(
                            competitionId: competitionContext?.competitionId,
                            label:
                                leaguePositionLabel(context, leagueName, rank),
                            textKey: const ValueKey('home-team-standing'),
                            style: Body2.style.copyWith(height: 1.3),
                            rankDelta: rankDelta,
                            movementKey:
                                const ValueKey('home-team-rank-movement'),
                            risingIcon: SvgPicture.asset(
                              'assets/standings/rank_up.svg',
                              width: 24,
                              height: 24,
                            ),
                            fallingIcon: Transform.flip(
                              flipY: true,
                              child: SvgPicture.asset(
                                'assets/standings/rank_down.svg',
                                width: 24,
                                height: 24,
                              ),
                            ),
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
                      clock: match.status == FixtureStatus.live
                          ? liveMatchClock
                          : null,
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
                      competitionId: last.competitionId,
                      fixture: last,
                      competitionName: competitionNameLabel(
                        context,
                        last.competitionId,
                        competitionRepository
                                .findById(last.competitionId)
                                ?.name ??
                            tr(context, 'Unknown League'),
                      ),
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
