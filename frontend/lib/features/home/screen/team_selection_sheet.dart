part of 'home_screen_features.dart';

class TeamSelectionSheet extends StatefulWidget {
  final int initialFavoriteTeamId;
  final List<Team> followingTeams;
  final FutureOr<void> Function(int teamId) onSwitch;

  const TeamSelectionSheet({
    super.key,
    required this.initialFavoriteTeamId,
    required this.followingTeams,
    required this.onSwitch,
  });

  // Static helper to show the sheet easily from anywhere
  static void show(
    BuildContext context, {
    required int initialFavoriteTeamId,
    required List<Team> followingTeams,
    required FutureOr<void> Function(int teamId) onSwitch,
  }) {
    final appColors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => TeamSelectionSheet(
        initialFavoriteTeamId: initialFavoriteTeamId,
        followingTeams: followingTeams,
        onSwitch: onSwitch,
      ),
    );
  }

  @override
  State<TeamSelectionSheet> createState() => _TeamSelectionSheetState();
}

class _TeamSelectionSheetState extends State<TeamSelectionSheet> {
  late List<Map<String, dynamic>> _followingTeams;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _followingTeams = widget.followingTeams.map((team) {
      return <String, dynamic>{
        'id': team.teamId,
        'name': team.name,
        'league': teamCompetitionContextResolver.labelFor(team.teamId),
        'logo': team.imagePath ?? '',
        'isSelected': team.teamId == widget.initialFavoriteTeamId,
      };
    }).toList();
  }

  Future<void> _switchTeam() async {
    if (_isSaving) return;
    final selected = _followingTeams.firstWhere(
      (team) => team['isSelected'] == true,
      orElse: () => _followingTeams.first,
    );
    setState(() => _isSaving = true);

    try {
      await widget.onSwitch(selected['id'] as int);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FavoriteTeamCooldownException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to change favorite team. Please try again.'),
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
                  "Following Teams",
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
          Expanded(
            child: ListView.builder(
              itemCount: _followingTeams.length,
              itemBuilder: (context, index) {
                final team = _followingTeams[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      team['logo'],
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) =>
                          teamLogoFallback(team['id'] as int, size: 24),
                    ),
                  ),
                  title: Text(
                    team['name'],
                    style: Body1_b.style,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(team['league'] ?? '', style: Body2.style),
                  trailing: team['isSelected']
                      ? Icon(Icons.check, color: colorScheme.onSurface)
                      : null,
                  onTap: _isSaving
                      ? null
                      : () {
                          setState(() {
                            for (var t in _followingTeams) {
                              t['isSelected'] = false;
                            }
                            team['isSelected'] = true;
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
              onPressed: _isSaving ? null : _switchTeam,
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
                      "SWITCH",
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
