import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/features/helper.dart';

class H2HTab extends StatefulWidget {
  final Fixture fixture;

  const H2HTab({super.key, required this.fixture});

  @override
  State<H2HTab> createState() => _H2HTabState();
}

class _H2HTabState extends State<H2HTab> {
  int _selectedMatches = 5;
  final List<int> _matchOptions = [5, 10, 20];

  // "AGAINST" means the opponent of the team the user actually follows, not
  // just whichever side happens to be away. If neither team in this fixture
  // is followed, there's no "my team" to take the perspective of, so it
  // falls back to the away team (i.e. against the home team).
  int get _againstTeamId {
    final homeId = widget.fixture.homeTeamId;
    final awayId = widget.fixture.awayTeamId;
    final following = currentUserPreferences.followedTeamIds.value;
    if (following.contains(homeId)) return awayId;
    if (following.contains(awayId)) return homeId;
    return awayId;
  }

  @override
  Widget build(BuildContext context) {
    final homeId = widget.fixture.homeTeamId;
    final awayId = widget.fixture.awayTeamId;

    final allH2H = fixtureRepository.headToHead(homeId, awayId);

    final h2hMatches = allH2H.take(_selectedMatches).toList();

    // WDL from home team's perspective
    int wins = 0, draws = 0, losses = 0;
    for (final f in h2hMatches) {
      final hs = f.homeScore ?? 0;
      final as_ = f.awayScore ?? 0;
      final homeIsOurHome = f.homeTeamId == homeId;
      if (hs == as_) {
        draws++;
      } else if ((hs > as_ && homeIsOurHome) || (as_ > hs && !homeIsOurHome)) {
        wins++;
      } else {
        losses++;
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildDropdownRow(),
          const SizedBox(height: 48),
          _buildWDLBox(wins, draws, losses),
          const SizedBox(height: 48),
          _buildBetsCard(),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 40),
            child: Text('PAST MATCHES', style: Body2_b.style),
          ),
          ...h2hMatches.map((f) {
            final home = teamRepository.findByIdOrUnknown(f.homeTeamId);
            final away = teamRepository.findByIdOrUnknown(f.awayTeamId);
            final leagueName =
                competitionRepository.findById(f.competitionId)?.name ??
                    'Unknown';
            final roundName = f.roundName?.trim();
            final competitionAndRound = roundName?.isNotEmpty ?? false
                ? '$leagueName · $roundName'
                : leagueName;
            return _buildPastMatchCard(
              home.shortCode ?? home.name,
              away.shortCode ?? away.name,
              home.imagePath ?? '',
              away.imagePath ?? '',
              home.teamId,
              away.teamId,
              f.homeScore?.toString() ?? '-',
              f.awayScore?.toString() ?? '-',
              competitionAndRound,
            );
          }),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildDropdownRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final surface = isDark ? AppPalette.lightGrey : AppPalette.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Functional dropdown
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedMatches,
                  dropdownColor: surface,
                  borderRadius: BorderRadius.circular(16),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.keyboard_arrow_down, color: foreground),
                  ),
                  style: Body2_b.style.copyWith(color: foreground),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMatches = val);
                  },
                  items: _matchOptions.map((n) {
                    return DropdownMenuItem<int>(
                      value: n,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'LAST $n MATCHES',
                          style: Body2_b.style.copyWith(color: foreground),
                        ),
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) => _matchOptions.map((n) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'LAST $_selectedMatches MATCHES',
                          style: Body2_b.style.copyWith(color: foreground),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('AGAINST', style: Body2_b.style),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: GestureDetector(
              // Match screen is on the root navigator; '/team/:id' is on the
              // shell's navigator. go() (not push()) so it actually surfaces.
              onTap: () => context.go('/team/$_againstTeamId'),
              child: Image.network(
                teamRepository.findByIdOrUnknown(_againstTeamId).imagePath ??
                    '',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    teamLogoFallback(_againstTeamId, size: 40),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWDLBox(int wins, int draws, int losses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('match-h2h-wdl-card'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.lightGrey : AppPalette.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWDLStat('$wins', 'Win'),
          _buildWDLStat('$draws', 'Draw'),
          _buildWDLStat('$losses', 'Lose'),
        ],
      ),
    );
  }

  Widget _buildWDLStat(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.lightGreyBox,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(value, style: Heading2.style.copyWith(color: foreground)),
        ),
        const SizedBox(height: 4),
        Text(label, style: Body1.style),
      ],
    );
  }

  Widget _buildBetsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BETS',
          style: Body2_b.style,
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('match-h2h-bets-card'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.lightGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EXPERT row
              Row(
                children: [
                  const Text('EXPERT', style: Body2_b.style),
                  const SizedBox(width: 6),
                  Icon(Icons.help_outline, color: foreground, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              _buildBar(
                values: [60, 20, 20],
                showCheckOnFirst: false,
              ),
              const SizedBox(height: 20),
              // USER row
              const Text('USER', style: Body2_b.style),
              const SizedBox(height: 12),
              _buildBar(
                values: [60, 30, 10],
                showCheckOnFirst: true,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBar(
      {required List<int> values, required bool showCheckOnFirst}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segments = [
      (values[0], false),
      (values[1], false),
      (values[2], true),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: List.generate(segments.length, (i) {
          final (value, isWhite) = segments[i];
          return Expanded(
            flex: value,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isWhite
                    ? (isDark ? Colors.white : AppPalette.lightGreyBox)
                    : i == 0
                        ? const Color(0xFFFF5B5B)
                        : (isDark ? AppPalette.darkGrey : AppPalette.black),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$value%',
                      style: Body2_b.style.copyWith(
                        color: isWhite ? AppPalette.black : AppPalette.white,
                      ),
                    ),
                    if (i == 0 && showCheckOnFirst) ...[
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPastMatchCard(
      String teamA,
      String teamB,
      String logoA,
      String logoB,
      int idA,
      int idB,
      String homeScore,
      String awayScore,
      String league) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.lightGrey : AppPalette.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/team/$idA'),
                child: ClipOval(
                  child: Image.network(
                    logoA,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        teamLogoFallback(idA, size: 32),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(teamA, style: Heading5.style),
              const Spacer(),
              _scoreBox(homeScore),
              const SizedBox(width: 8),
              _scoreBox(awayScore),
              const Spacer(),
              Text(teamB, style: Heading5.style),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go('/team/$idB'),
                child: ClipOval(
                  child: Image.network(
                    logoB,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        teamLogoFallback(idB, size: 32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(league, style: Body2.style),
        ],
      ),
    );
  }

  Widget _scoreBox(String score) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkGrey : AppPalette.lightGreyBox,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(score, style: Heading2.style.copyWith(color: foreground)),
    );
  }
}
