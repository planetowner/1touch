part of 'team_screen_features.dart';

class InjuryStatus extends StatefulWidget {
  const InjuryStatus({
    super.key,
    this.teams,
    this.repository,
  });

  final Object? teams;
  final TeamInjuryRepository? repository;

  @override
  State<InjuryStatus> createState() => _InjuryStatusState();
}

class _InjuryStatusState extends State<InjuryStatus> {
  TeamInjuryReport? _report;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;

  TeamInjuryRepository get _repository =>
      widget.repository ?? teamInjuryRepository;

  int? get _teamId {
    if (widget.teams is Map<String, dynamic>) {
      return (widget.teams as Map<String, dynamic>)['id'] as int?;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(InjuryStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTeamId = oldWidget.teams is Map<String, dynamic>
        ? (oldWidget.teams as Map<String, dynamic>)['id'] as int?
        : null;
    if (_teamId != oldTeamId || widget.repository != oldWidget.repository) {
      _startLoad();
    }
  }

  void _startLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cached = teamId == null ? null : _repository.cachedForTeam(teamId);

    _report = cached;
    _isLoading = teamId != null && cached == null;
    _loadFailed = false;

    if (_isLoading) {
      unawaited(_loadInjuries(teamId!, requestId));
    }
  }

  Future<void> _loadInjuries(int teamId, int requestId) async {
    try {
      final report = await _repository.loadForTeam(teamId);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _retryLoad() => setState(_startLoad);

  @override
  Widget build(BuildContext context) {
    final players = _report?.players ?? const <InjuredTeamPlayer>[];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: _isLoading
          ? const Center(
              child: SizedBox.square(
                key: ValueKey('injury-loading'),
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : _loadFailed
              ? Row(
                  key: const ValueKey('injury-error'),
                  children: [
                    Expanded(
                      child: Text(
                        'Unable to load injuries',
                        style: Body2.style,
                      ),
                    ),
                    TextButton(
                      onPressed: _retryLoad,
                      child: const Text('RETRY'),
                    ),
                  ],
                )
              : players.isEmpty
                  ? Text(
                      'No current injuries',
                      key: const ValueKey('injury-empty'),
                      style: Body2.style,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...players.map(_buildInjuryTile),
                      ],
                    ),
    );
  }

  Widget _buildInjuryTile(InjuredTeamPlayer player) {
    final appColors = AppColors.of(context);
    return Container(
      key: ValueKey('injured-player-${player.playerId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 37,
            backgroundColor: appColors.cardBackground,
            child: ClipOval(
              child: player.playerImage == null || player.playerImage!.isEmpty
                  ? Image.asset(
                      'assets/messi.png',
                      width: 74,
                      height: 74,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      player.playerImage!,
                      width: 74,
                      height: 74,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/messi.png',
                        width: 74,
                        height: 74,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.jerseyNumber?.toString() ?? '#',
                      key: ValueKey('injury-jersey-${player.playerId}'),
                      style: Body1_b.style,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.playerName,
                        style: Body1_b.style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...player.injuries.map(
                  (injury) => Text(
                    _injuryLabel(injury),
                    key: ValueKey('injury-${injury.sidelineId}'),
                    style: Body2.style,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _injuryLabel(TeamPlayerInjury injury) {
    final start = injury.startDate;
    final end = injury.endDate;
    if (start == null && end == null) return injury.typeName;

    final period = switch ((start, end)) {
      (final DateTime start, final DateTime end) =>
        '${_formatInjuryDate(start)} – ${_formatInjuryDate(end)}',
      (final DateTime start, null) => 'Since ${_formatInjuryDate(start)}',
      (null, final DateTime end) => 'Through ${_formatInjuryDate(end)}',
      _ => '',
    };
    return '${injury.typeName} • $period';
  }

  String _formatInjuryDate(DateTime date) {
    // Injury dates are provider date-only values, so timezone conversion would
    // risk shifting the displayed calendar day.
    return DateFormat('MMM d, yyyy').format(date);
  }
}
