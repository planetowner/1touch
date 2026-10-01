part of 'home_screen_features.dart';

class TeamSelectionSheet extends StatefulWidget {
  final int initialTeamId;
  final int favoriteTeamId;
  final List<Team> followingTeams;
  final FutureOr<void> Function(int teamId) onSwitch;
  final StandingRepository? standingsRepository;

  const TeamSelectionSheet({
    super.key,
    required this.initialTeamId,
    required this.favoriteTeamId,
    required this.followingTeams,
    required this.onSwitch,
    this.standingsRepository,
  });

  // Static helper to show the sheet easily from anywhere
  static void show(
    BuildContext context, {
    required int initialTeamId,
    required int favoriteTeamId,
    required List<Team> followingTeams,
    required FutureOr<void> Function(int teamId) onSwitch,
    StandingRepository? standingsRepository,
  }) {
    final appColors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: appColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => TeamSelectionSheet(
        initialTeamId: initialTeamId,
        favoriteTeamId: favoriteTeamId,
        followingTeams: followingTeams,
        onSwitch: onSwitch,
        standingsRepository: standingsRepository,
      ),
    );
  }

  @override
  State<TeamSelectionSheet> createState() => _TeamSelectionSheetState();
}

class _TeamSelectionSheetState extends State<TeamSelectionSheet> {
  late final List<_TeamSelectionOption> _followingTeams;
  late int _selectedTeamId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTeamId = widget.initialTeamId;
    _followingTeams = widget.followingTeams
        .where((team) => teamPageEligibility.supports(team.teamId))
        .map((team) {
      final competition = teamCompetitionContextResolver.resolve(team.teamId)!;
      return _TeamSelectionOption(
        team: team,
        competition: competition,
        // 순위 화면과 같은 저장소를 써서 같은 리그의 중복 요청과 표기 차이를 줄여요.
        standings: (widget.standingsRepository ?? standingRepository)
            .loadForCompetition(competition.competitionId!,
                seasonId: competition.seasonId),
      );
    }).toList(growable: false);
  }

  Future<void> _switchTeam() async {
    if (_isSaving || _followingTeams.isEmpty) return;
    final selected = _followingTeams.firstWhere(
      (option) => option.team.teamId == _selectedTeamId,
      orElse: () => _followingTeams.first,
    );
    setState(() => _isSaving = true);

    try {
      await widget.onSwitch(selected.team.teamId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'Unable to load Home.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  tr(context, "Following Teams"),
                  style: Heading5.style,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            fit: FlexFit.loose,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _followingTeams.length,
              itemBuilder: (context, index) {
                final option = _followingTeams[index];
                final team = option.team;
                final competition = option.competition;
                return ListTile(
                  key: ValueKey('team-selection-${team.teamId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      team.imagePath ?? '',
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) =>
                          teamLogoFallback(team.teamId, size: 24),
                    ),
                  ),
                  title: TeamNameWithFavoriteStar(
                    teamId: team.teamId,
                    name: team.name,
                    // 체크는 이번 선택을, 별은 저장된 최애팀을 나타내요.
                    isFavorite: team.teamId == widget.favoriteTeamId,
                    style: Body1_b.style,
                  ),
                  subtitle: FutureBuilder<List<Standing>>(
                    future: option.standings,
                    builder: (context, snapshot) => Text(
                      leaguePositionLabel(
                        context,
                        competitionNameLabel(context, competition.competitionId,
                            competition.competitionName ?? ''),
                        snapshot.data
                            ?.where((row) => row.teamId == team.teamId)
                            .firstOrNull
                            ?.position,
                      ),
                      style: Body2.style,
                    ),
                  ),
                  trailing: team.teamId == _selectedTeamId
                      ? Icon(Icons.check, color: colorScheme.onSurface)
                      : null,
                  onTap: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _selectedTeamId = team.teamId;
                          });
                        },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isSaving || _followingTeams.isEmpty ? null : _switchTeam,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      tr(context, "SWITCH"),
                      style:
                          Body2_b.style.copyWith(color: colorScheme.onPrimary),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamSelectionOption {
  const _TeamSelectionOption({
    required this.team,
    required this.competition,
    required this.standings,
  });

  final Team team;
  final TeamCompetitionContext competition;
  final Future<List<Standing>> standings;
}
