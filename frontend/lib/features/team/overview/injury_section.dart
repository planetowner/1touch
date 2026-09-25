part of 'team_screen_features.dart';

class InjuryStatus extends StatefulWidget {
  const InjuryStatus({
    super.key,
    this.teams,
    this.repository,
    this.onUnavailable,
  });

  final Object? teams;
  final TeamInjuryRepository? repository;
  final VoidCallback? onUnavailable;

  @override
  State<InjuryStatus> createState() => _InjuryStatusState();
}

class _InjuryStatusState extends State<InjuryStatus> {
  TeamInjuryReport? _report;
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _isUnavailable = false;
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
    _isUnavailable = false;

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
    } on TeamFeatureUnavailableException {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _isUnavailable = true;
      });
      widget.onUnavailable?.call();
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
    if (_isUnavailable) {
      return const SizedBox.shrink(
        key: ValueKey('injury-unavailable'),
      );
    }
    final today = time.clock.now().toLocal();
    // 종료일이 지나도 공급자의 현재 부상 명단에 남아 있으면 계속 보여줘요.
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
                        tr(context, 'Unable to load injuries'),
                        style: Body2.style,
                      ),
                    ),
                    TextButton(
                      onPressed: _retryLoad,
                      child: Text(tr(context, 'RETRY')),
                    ),
                  ],
                )
              : players.isEmpty
                  ? Text(
                      tr(context, 'No current injuries'),
                      key: const ValueKey('injury-empty'),
                      style: Body2.style,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...players
                            .map((player) => _buildInjuryTile(player, today)),
                      ],
                    ),
    );
  }

  Widget _buildInjuryTile(InjuredTeamPlayer player, DateTime today) {
    final appColors = AppColors.of(context);
    final content = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 37,
            backgroundColor: appColors.subtleBackground,
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
                      style: Heading5.style.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        playerNameLabel(
                            context, player.playerId, player.playerName),
                        style: Heading5.style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...player.injuries.map(
                  (injury) => Text(
                    _injuryLabel(injury, today),
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
    return Semantics(
      button: true,
      label: tr(context, 'Open {name}', {
        'name': playerNameLabel(context, player.playerId, player.playerName)
      }),
      child: InkWell(
        key: ValueKey('injured-player-${player.playerId}'),
        onTap: () => openPlayerPage(context, player.playerId.toString()),
        child: content,
      ),
    );
  }

  String _injuryLabel(TeamPlayerInjury injury, DateTime today) {
    final locale = Localizations.localeOf(context);
    final typeName = injuryTypeLabel(
      locale,
      injury.typeId,
      injury.typeName,
    );
    final returnLabel = injuryReturnLabel(
      injury.daysUntilReturn(today),
      locale: locale,
    );
    return '$typeName · $returnLabel';
  }
}
