import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_providers;
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/fixture_labels.dart';

class H2HTab extends StatefulWidget {
  final Fixture fixture;
  final FixtureRepository? fixtureRepository;
  final BettingController bettingController;

  const H2HTab({
    super.key,
    required this.fixture,
    required this.bettingController,
    this.fixtureRepository,
  });

  @override
  State<H2HTab> createState() => _H2HTabState();
}

class _H2HTabState extends State<H2HTab> {
  int _selectedMatches = 5;
  final List<int> _matchOptions = [5, 10, 20];
  List<Fixture> _h2hMatches = const [];
  bool _isLoading = true;
  bool _hasLoadError = false;
  int _latestRequestId = 0;

  FixtureRepository get _fixtureRepository =>
      widget.fixtureRepository ?? fixture_providers.fixtureRepository;

  @override
  void initState() {
    super.initState();
    currentUserPreferences.favoriteTeamId.addListener(_handleFavoriteChanged);
    _loadHeadToHead();
  }

  @override
  void dispose() {
    currentUserPreferences.favoriteTeamId
        .removeListener(_handleFavoriteChanged);
    super.dispose();
  }

  void _handleFavoriteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(H2HTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fixture.fixtureId != oldWidget.fixture.fixtureId ||
        widget.fixtureRepository != oldWidget.fixtureRepository) {
      _selectedMatches = 5;
      _loadHeadToHead();
    }
  }

  Future<void> _loadHeadToHead() async {
    final requestId = ++_latestRequestId;
    final fixtureId = widget.fixture.fixtureId;
    final limit = _selectedMatches;
    final repository = _fixtureRepository;

    setState(() {
      _isLoading = true;
      _hasLoadError = false;
      _h2hMatches = const [];
    });

    try {
      final loaded = await repository.loadHeadToHead(fixtureId, limit: limit);
      if (!mounted || requestId != _latestRequestId) return;
      setState(() {
        _h2hMatches = loaded;
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _latestRequestId) return;
      setState(() {
        _hasLoadError = true;
        _isLoading = false;
      });
    }
  }

  int get _perspectiveTeamId {
    final favoriteId = currentUserPreferences.favoriteTeamId.value;
    if (favoriteId == widget.fixture.homeTeamId ||
        favoriteId == widget.fixture.awayTeamId) {
      return favoriteId;
    }
    return widget.fixture.homeTeamId;
  }

  int get _againstTeamId {
    return _perspectiveTeamId == widget.fixture.homeTeamId
        ? widget.fixture.awayTeamId
        : widget.fixture.homeTeamId;
  }

  @override
  Widget build(BuildContext context) {
    final perspectiveTeamId = _perspectiveTeamId;

    // WDL from the user's favorite-team perspective when it is participating.
    int wins = 0, draws = 0, losses = 0;
    for (final f in _h2hMatches) {
      final hs = f.homeScore ?? 0;
      final as_ = f.awayScore ?? 0;
      final perspectiveIsHome = f.homeTeamId == perspectiveTeamId;
      if (hs == as_) {
        draws++;
      } else if ((hs > as_ && perspectiveIsHome) ||
          (as_ > hs && !perspectiveIsHome)) {
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
          if (_isLoading)
            const Padding(
              key: ValueKey('match-h2h-loading'),
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasLoadError)
            Padding(
              key: const ValueKey('match-h2h-error'),
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      tr(context, 'Unable to load head-to-head matches.'),
                      style: Body2_b.style,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadHeadToHead,
                      child: Text(tr(context, 'RETRY')),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _buildWDLBox(wins, draws, losses),
            const SizedBox(height: 48),
            _buildBetsCard(),
            Padding(
              padding: EdgeInsets.only(bottom: 8, top: 40),
              child: Text(tr(context, 'PAST MATCHES'), style: Body2_b.style),
            ),
            if (_h2hMatches.isEmpty)
              Padding(
                key: ValueKey('match-h2h-empty'),
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    tr(context, 'No previous meetings found.'),
                    style: Body2.style,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._h2hMatches.map((f) {
                final home = fixtureHomeTeam(f, teamRepository);
                final away = fixtureAwayTeam(f, teamRepository);
                final leagueName = competitionNameLabel(
                    context,
                    f.competitionId,
                    competitionRepository.findById(f.competitionId)?.name ??
                        'Unknown');
                final roundLabel = fixtureRoundLabel(f,
                    locale: Localizations.localeOf(context));
                final competitionAndRound =
                    fixtureCompetitionLabel(context, f) ??
                        (roundLabel != null
                            ? '$leagueName · $roundLabel'
                            : leagueName);
                return GestureDetector(
                  key: ValueKey('match-h2h-fixture-${f.fixtureId}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(
                    '/match/${f.fixtureId}?status=${f.status.name}',
                    extra: f,
                  ),
                  child: _buildPastMatchCard(
                    home.shortCode ??
                        teamNameLabel(context, home.teamId, home.name),
                    away.shortCode ??
                        teamNameLabel(context, away.teamId, away.name),
                    home.imagePath ?? '',
                    away.imagePath ?? '',
                    home.teamId,
                    away.teamId,
                    f.homeScore?.toString() ?? '-',
                    f.awayScore?.toString() ?? '-',
                    competitionAndRound,
                  ),
                );
              }),
          ],
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildDropdownRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final surface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final againstTeam = _againstTeamId == widget.fixture.homeTeamId
        ? fixtureHomeTeam(widget.fixture, teamRepository)
        : fixtureAwayTeam(widget.fixture, teamRepository);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Functional dropdown
          Flexible(
            child: AppDropdown<int>(
              key: const ValueKey('match-h2h-limit-dropdown'),
              width: 152,
              value: _selectedMatches,
              backgroundColor: surface,
              foregroundColor: foreground,
              textStyle: Body2_b.style,
              options: _matchOptions
                  .map(
                    (count) => AppDropdownOption<int>(
                      value: count,
                      label: tr(
                        context,
                        'Last {count} matches',
                        {'count': count},
                      ).toUpperCase(),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == _selectedMatches) return;
                setState(() => _selectedMatches = value);
                _loadHeadToHead();
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(tr(context, 'AGAINST'), style: Body2_b.style),
          const SizedBox(width: 8),
          Container(
            key: ValueKey('match-h2h-against-team-$_againstTeamId'),
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: GestureDetector(
              // Match screen is on the root navigator; '/team/:id' is on the
              // shell's navigator. go() (not push()) so it actually surfaces.
              onTap: isTeamPageSupported(_againstTeamId)
                  ? () => openTeamPage(context, _againstTeamId)
                  : null,
              child: Image.network(
                againstTeam.imagePath ?? '',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    teamLogoFallback(_againstTeamId, size: 40),
              ),
            ),
          ),
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
        boxShadow: appCardShadows(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWDLStat('$wins', tr(context, 'Win'),
              valueKey: 'match-h2h-win-value'),
          _buildWDLStat('$draws', tr(context, 'Draw'),
              valueKey: 'match-h2h-draw-value'),
          _buildWDLStat('$losses', tr(context, 'Lose'),
              valueKey: 'match-h2h-loss-value'),
        ],
      ),
    );
  }

  Widget _buildWDLStat(
    String value,
    String label, {
    required String valueKey,
  }) {
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
          child: Text(
            value,
            key: ValueKey(valueKey),
            style: Heading2.style.copyWith(color: foreground),
          ),
        ),
        const SizedBox(height: 4),
        Text(tr(context, label), style: Body1.style),
      ],
    );
  }

  Widget _buildBetsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeTeam = fixtureHomeTeam(widget.fixture, teamRepository);
    final awayTeam = fixtureAwayTeam(widget.fixture, teamRepository);
    final perspectiveIsHome = _perspectiveTeamId == widget.fixture.homeTeamId;
    final anchorTeam = perspectiveIsHome ? homeTeam : awayTeam;
    final opponentTeam = perspectiveIsHome ? awayTeam : homeTeam;
    final comparisonColors = TeamComparisonColorResolver.resolve(
      anchorTeamName: anchorTeam.name,
      anchorPrimaryFallback: Color(anchorTeam.primaryColor),
      opponentTeamName: opponentTeam.name,
      opponentPrimaryFallback: Color(opponentTeam.primaryColor),
      background: isDark ? AppPalette.lightGrey : AppPalette.white,
    );
    final homeColor =
        perspectiveIsHome ? comparisonColors.anchor : comparisonColors.opponent;
    final awayColor =
        perspectiveIsHome ? comparisonColors.opponent : comparisonColors.anchor;
    final drawColor = Color.lerp(homeColor, awayColor, 0.5)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, 'BETS'), style: Body2_b.style),
        const SizedBox(height: 16),
        BettingParticipationCard(
          controller: widget.bettingController,
          barColors: [homeColor, drawColor, awayColor],
        ),
      ],
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
    String league,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.lightGrey : AppPalette.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: appCardShadows(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: isTeamPageSupported(idA)
                    ? () => openTeamPage(context, idA)
                    : null,
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
              Expanded(
                child: Text(
                  teamA,
                  style: Heading5.style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _scoreBox(homeScore),
              const SizedBox(width: 8),
              _scoreBox(awayScore),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  teamB,
                  style: Heading5.style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isTeamPageSupported(idB)
                    ? () => openTeamPage(context, idB)
                    : null,
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
