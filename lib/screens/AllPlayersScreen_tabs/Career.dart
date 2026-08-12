import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/teams/mock/team_trophy_catalog.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/team_trophy.dart';

class CareerTab extends StatefulWidget {
  final Player player;

  const CareerTab({super.key, required this.player});

  @override
  State<CareerTab> createState() => _CareerTabState();
}

class _CareerTabState extends State<CareerTab> {
  static const _allCompetitions = 'ALL LEAGUES';

  String _trophyFilter = 'TEAM';
  String _competitionFilter = _allCompetitions;
  final Set<String> _expandedSeasons = {};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  AppColors get _appColors => AppColors.of(context);
  Color get _foreground => Theme.of(context).colorScheme.onSurface;
  Color get _sectionSurface =>
      _isDark ? const Color(0xFF3D3D3D) : AppPalette.white;

  @override
  void initState() {
    super.initState();
    _expandNewestSeason();
  }

  @override
  void didUpdateWidget(covariant CareerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.id != widget.player.id) {
      _trophyFilter = 'TEAM';
      _competitionFilter = _allCompetitions;
      _expandedSeasons.clear();
      _expandNewestSeason();
    }
  }

  void _expandNewestSeason() {
    if (widget.player.careerSeasons.isNotEmpty) {
      _expandedSeasons.add(_seasonKey(widget.player.careerSeasons.first));
    }
  }

  String _seasonKey(PlayerCareerSeason season) =>
      '${season.teamId}-${season.seasonLabel}';

  Team? _teamFor(int teamId) => teamRepository.findById(teamId);

  List<String> get _competitionOptions {
    final codes = widget.player.careerSeasons
        .expand((season) => season.competitions)
        .map((competition) => competition.competitionCode)
        .toSet()
        .toList()
      ..sort();
    return [_allCompetitions, ...codes];
  }

  List<PlayerCareerSeason> get _visibleSeasons {
    if (_competitionFilter == _allCompetitions) {
      return widget.player.careerSeasons;
    }
    return widget.player.careerSeasons
        .where(
          (season) => season.competitions.any(
            (competition) => competition.competitionCode == _competitionFilter,
          ),
        )
        .toList(growable: false);
  }

  List<_TeamTrophyGroup> get _teamTrophyGroups {
    final careerKeys = widget.player.careerSeasons
        .map((season) => '${season.teamId}-${season.seasonLabel}')
        .toSet();
    final relevant = mockTeamTrophies
        .where(
          (trophy) =>
              careerKeys.contains('${trophy.teamId}-${trophy.seasonLabel}'),
        )
        .toList(growable: false);
    final byTeam = <int, List<TeamTrophy>>{};
    for (final trophy in relevant) {
      byTeam.putIfAbsent(trophy.teamId, () => []).add(trophy);
    }

    final teamOrder = widget.player.careerSeasons
        .map((season) => season.teamId)
        .toSet()
        .toList(growable: false);
    return teamOrder
        .where(byTeam.containsKey)
        .map(
          (teamId) => _TeamTrophyGroup(
            team: _teamFor(teamId),
            teamId: teamId,
            trophies: byTeam[teamId]!,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('player-career-scroll'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 144),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrophyBlock(),
          const SizedBox(height: 48),
          _buildHistoryBlock(),
        ],
      ),
    );
  }

  Widget _buildTrophyBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TROPHIES', style: Body2_b.style),
            _FilterButton(
              key: const Key('career-trophy-filter'),
              label: _trophyFilter,
              onTap: () => _showFilterSheet(
                options: const ['TEAM', 'PERSONAL'],
                selected: _trophyFilter,
                onSelected: (option) => setState(() {
                  _trophyFilter = option;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('player-career-trophies-card'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _sectionSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: _trophyFilter == 'TEAM'
              ? _buildTeamTrophies()
              : _buildPersonalAwards(),
        ),
      ],
    );
  }

  Widget _buildTeamTrophies() {
    final groups = _teamTrophyGroups;
    if (groups.isEmpty) {
      return _emptyMessage('No team trophies for these career seasons');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          _buildTeamTrophyGroup(groups[index]),
          if (index != groups.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Divider(color: _appColors.divider, height: 1),
            ),
        ],
      ],
    );
  }

  Widget _buildTeamTrophyGroup(_TeamTrophyGroup group) {
    final byName = <String, List<TeamTrophy>>{};
    for (final trophy in group.trophies) {
      byName.putIfAbsent(trophy.name, () => []).add(trophy);
    }
    final namedGroups = byName.entries
        .map((entry) => _NamedTrophyGroup(entry.key, entry.value))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClubHeader(
          teamId: group.teamId,
          name: (group.team?.name ?? 'Team ${group.teamId}').toUpperCase(),
          count: group.trophies.length,
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < namedGroups.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == namedGroups.length - 1 ? 0 : 18,
            ),
            child: _buildTrophyItem(
              namedGroups[index].name,
              namedGroups[index]
                  .trophies
                  .map((trophy) => trophy.seasonLabel)
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }

  Widget _buildPersonalAwards() {
    final awards = widget.player.personalAwards;
    if (awards.isEmpty) {
      return _emptyMessage('No personal awards in the mock dataset');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < awards.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == awards.length - 1 ? 0 : 18,
            ),
            child: _buildTrophyItem(
              awards[index].name,
              awards[index].seasons,
            ),
          ),
      ],
    );
  }

  Widget _emptyMessage(String message) => Text(
        message,
        style: Body1.style.copyWith(color: _appColors.mutedForeground),
      );

  Widget _buildClubHeader({
    required int teamId,
    required String name,
    required int count,
  }) {
    final logo = teamLogoAsset(teamId);
    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: logo == null
              ? Icon(
                  Icons.shield_outlined,
                  color: _appColors.mutedForeground,
                  size: 24,
                )
              : Image.asset(logo, fit: BoxFit.contain),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: Body2_b.style)),
        Text('$count', style: Body2_b.style),
      ],
    );
  }

  Widget _buildTrophyItem(String title, List<String> seasons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: _foreground,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: Heading5.style)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: seasons
              .map(
                (season) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    season,
                    style: Body2.style.copyWith(color: AppPalette.white),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildHistoryBlock() {
    final seasons = _visibleSeasons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('HISTORY', style: Body2_b.style),
            _FilterButton(
              key: const Key('career-competition-filter'),
              label: _competitionFilter,
              onTap: () => _showFilterSheet(
                options: _competitionOptions,
                selected: _competitionFilter,
                onSelected: (option) => setState(() {
                  _competitionFilter = option;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('player-career-history-card'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: _sectionSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: seasons.isEmpty
              ? _emptyMessage('No history for this competition')
              : Column(
                  children: [
                    _buildTableHeader(),
                    const SizedBox(height: 8),
                    for (var index = 0; index < seasons.length; index++)
                      _buildSeasonGroup(
                        season: seasons[index],
                        nextSeason: index + 1 < seasons.length
                            ? seasons[index + 1]
                            : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    final style = Body2.style.copyWith(color: _appColors.mutedForeground);
    return Row(
      children: [
        Expanded(flex: 2, child: Text('Season', style: style)),
        Expanded(flex: 3, child: Text('Team', style: style)),
        Expanded(
          flex: 2,
          child: Text('MP', textAlign: TextAlign.center, style: style),
        ),
        Expanded(
          flex: 2,
          child: Text('WR', textAlign: TextAlign.center, style: style),
        ),
        Expanded(
          flex: 2,
          child: Text('Rating', textAlign: TextAlign.center, style: style),
        ),
        const SizedBox(width: 22),
      ],
    );
  }

  Widget _buildSeasonGroup({
    required PlayerCareerSeason season,
    required PlayerCareerSeason? nextSeason,
  }) {
    final key = _seasonKey(season);
    final isExpanded = _expandedSeasons.contains(key);
    final team = _teamFor(season.teamId);
    final competitions = _competitionFilter == _allCompetitions
        ? season.competitions
        : season.competitions
            .where(
              (competition) =>
                  competition.competitionCode == _competitionFilter,
            )
            .toList(growable: false);
    final selectedCompetition =
        _competitionFilter == _allCompetitions ? null : competitions.first;
    final appearances = selectedCompetition?.appearances ?? season.appearances;
    final winRate =
        selectedCompetition?.winRatePercent ?? season.winRatePercent;
    final rating = selectedCompetition?.rating ?? season.rating;
    final changesClub =
        nextSeason != null && nextSeason.teamId != season.teamId;

    return Column(
      children: [
        InkWell(
          key: Key('career-season-$key'),
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedSeasons.remove(key);
            } else {
              _expandedSeasons.add(key);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(season.seasonLabel, style: Body2_b.style),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _buildTeamLogo(season.teamId),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          team?.shortCode ?? '${season.teamId}',
                          overflow: TextOverflow.ellipsis,
                          style: Body2_b.style,
                        ),
                      ),
                    ],
                  ),
                ),
                _tableValue('$appearances'),
                _tableValue('$winRate%'),
                Expanded(
                  flex: 2,
                  child: Center(child: _ratingBadge(rating)),
                ),
                SizedBox(
                  width: 22,
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _foreground,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          for (final competition in competitions)
            _buildCompetitionRow(season, competition),
        if (changesClub)
          Divider(color: _appColors.divider, height: 1)
        else
          const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildCompetitionRow(
    PlayerCareerSeason season,
    PlayerCompetitionStats competition,
  ) {
    return Padding(
      key: Key(
        'career-competition-${_seasonKey(season)}-${competition.competitionCode}',
      ),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              competition.competitionName,
              overflow: TextOverflow.ellipsis,
              style: Body2_b.style.copyWith(color: _appColors.mutedForeground),
            ),
          ),
          _tableValue(
            '${competition.appearances}',
            color: _appColors.mutedForeground,
          ),
          _tableValue(
            '${competition.winRatePercent}%',
            color: _appColors.mutedForeground,
          ),
          Expanded(
            flex: 2,
            child: Center(child: _ratingBadge(competition.rating)),
          ),
          const SizedBox(width: 22),
        ],
      ),
    );
  }

  Widget _tableValue(String value, {Color? color}) {
    return Expanded(
      flex: 2,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: Body2_b.style.copyWith(color: color ?? _foreground),
      ),
    );
  }

  Widget _ratingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rating.toStringAsFixed(1),
        style: Body2_b.style.copyWith(color: AppPalette.white),
      ),
    );
  }

  Widget _buildTeamLogo(int teamId) {
    final logo = teamLogoAsset(teamId);
    return SizedBox(
      width: 22,
      height: 22,
      child: logo == null
          ? Icon(
              Icons.shield_outlined,
              color: _appColors.mutedForeground,
              size: 18,
            )
          : Image.asset(logo, fit: BoxFit.contain),
    );
  }

  Future<void> _showFilterSheet({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _isDark ? AppPalette.darkGrey : AppPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: options
              .map(
                (option) => ListTile(
                  title: Text(
                    option.toUpperCase(),
                    style: Body2_b.style.copyWith(
                      color: selected == option
                          ? _foreground
                          : _appColors.mutedForeground,
                    ),
                  ),
                  trailing: selected == option
                      ? Icon(Icons.check, color: _foreground)
                      : null,
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(sheetContext);
                  },
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FilterButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: isDark ? const Color(0xFF3D3D3D) : AppPalette.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: Body2_b.style.copyWith(color: foreground),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down,
                color: foreground,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamTrophyGroup {
  final Team? team;
  final int teamId;
  final List<TeamTrophy> trophies;

  const _TeamTrophyGroup({
    required this.team,
    required this.teamId,
    required this.trophies,
  });
}

class _NamedTrophyGroup {
  final String name;
  final List<TeamTrophy> trophies;

  const _NamedTrophyGroup(this.name, this.trophies);
}
