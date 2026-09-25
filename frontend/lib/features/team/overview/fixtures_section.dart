part of 'team_screen_features.dart';

class Fixtures extends StatefulWidget {
  Fixtures({super.key, this.teams});

  final teams;

  @override
  State<Fixtures> createState() => _FixturesState();
}

class _FixturesState extends State<Fixtures> {
  @override
  Widget build(BuildContext context) {
    if (widget.teams == null) return const SizedBox.shrink();
    if (widget.teams is! Map<String, dynamic>) return const SizedBox.shrink();

    final map = widget.teams as Map<String, dynamic>;
    final Fixture? match = map['next_match'] as Fixture?;
    final Fixture? lastMatch = map['last_match'] as Fixture?;
    final competitionId = match?.competitionId ?? lastMatch?.competitionId;
    final leagueName = competitionId == null
        ? tr(context, 'Unknown League')
        : competitionRepository.findById(competitionId)?.name ??
            'Unknown League';

    if (match == null && lastMatch == null) return const SizedBox.shrink();
    final appColors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final nextMatchBackground =
        isLight ? AppPalette.white : appColors.subtleBackground;
    final lastMatchBackground =
        isLight ? AppPalette.lightGreyBox : appColors.cardBackground;

    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          key: const ValueKey('team-overview-fixtures-card'),
          padding: EdgeInsets.only(bottom: isLight ? 0 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: appColors.cardBackground,
            boxShadow: appCardShadows(context),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (match != null)
                GestureDetector(
                  onTap: () => context.push(
                    '/match/${match.fixtureId}',
                    extra: match,
                  ),
                  child: MatchCard(
                    match: match,
                    leagueName: leagueName,
                    backgroundColor: nextMatchBackground,
                  ),
                ),
              if (lastMatch != null)
                GestureDetector(
                  onTap: () => context.push(
                    '/match/${lastMatch.fixtureId}?status=${lastMatch.status.name}',
                    extra: lastMatch,
                  ),
                  child: () {
                    final home = fixtureHomeTeam(lastMatch, teamRepository);
                    final away = fixtureAwayTeam(lastMatch, teamRepository);
                    return MatchCard2(
                      date: relativeDateLabel(lastMatch.kickoff,
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
                      homeScore: lastMatch.homeScore ?? 0,
                      awayScore: lastMatch.awayScore ?? 0,
                      backgroundColor: lastMatchBackground,
                      contentPadding: isLight
                          ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
                          : null,
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
