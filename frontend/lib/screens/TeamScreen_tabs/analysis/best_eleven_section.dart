part of '../Analysis.dart';

class BestElevenSection extends StatefulWidget {
  final Map<String, dynamic>? team;
  final BestElevenRepository? repository;

  const BestElevenSection({
    super.key,
    required this.team,
    this.repository,
  });

  @override
  State<BestElevenSection> createState() => _BestElevenSectionState();
}

class _BestElevenSectionState extends State<BestElevenSection> {
  TeamBestEleven? _lineup;
  List<BestElevenFormationOption> _formations = const [];
  String? _selectedFormation;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;

  BestElevenRepository get _repository =>
      widget.repository ?? bestElevenRepository;

  int? get _teamId => widget.team?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _startDefaultLoad();
  }

  @override
  void didUpdateWidget(BestElevenSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_teamId != oldWidget.team?['id'] ||
        widget.repository != oldWidget.repository) {
      _startDefaultLoad();
    }
  }

  void _startDefaultLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cached = teamId == null ? null : _repository.cachedForTeam(teamId);

    _lineup = cached;
    _formations = cached?.formations ?? const [];
    _selectedFormation = cached?.formation;
    _isLoading = teamId != null && cached == null;
    _loadFailed = false;

    if (_isLoading) {
      unawaited(_loadLineup(teamId!, requestId));
    }
  }

  Future<void> _loadLineup(
    int teamId,
    int requestId, {
    String? formation,
  }) async {
    try {
      final lineup = await _repository.loadForTeam(
        teamId,
        formation: formation,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _lineup = lineup;
        if (lineup != null) {
          _formations = lineup.formations;
          _selectedFormation = lineup.formation;
        }
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

  void _changeFormation(String formation) {
    final teamId = _teamId;
    if (teamId == null || formation == _selectedFormation) return;

    final requestId = ++_loadRequestId;
    final cached = _repository.cachedForTeam(teamId, formation: formation);
    setState(() {
      _selectedFormation = formation;
      _lineup = cached;
      if (cached != null) _formations = cached.formations;
      _isLoading = cached == null;
      _loadFailed = false;
    });

    if (cached == null) {
      unawaited(_loadLineup(teamId, requestId, formation: formation));
    }
  }

  void _retryLoad() {
    final teamId = _teamId;
    if (teamId == null) return;

    final requestId = ++_loadRequestId;
    final formation = _selectedFormation;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    unawaited(_loadLineup(teamId, requestId, formation: formation));
  }

  String _formationLabel(BestElevenFormationOption option) {
    final percentage = option.usagePercentage;
    if (percentage == null) return option.formation;
    final formatted = percentage == percentage.roundToDouble()
        ? percentage.toInt().toString()
        : percentage.toStringAsFixed(1);
    return '${option.formation} ($formatted%)';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Dropdown
          _AnalysisSectionHeader(
            title: 'BEST ELEVEN',
            trailing: _formations.isEmpty
                ? null
                : Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    decoration: BoxDecoration(
                      color: appColors.subtleBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('analysis-formation-filter'),
                        value: _selectedFormation,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        dropdownColor: appColors.cardBackground,
                        style: Body2_b.style.copyWith(color: colors.onSurface),
                        onChanged: _isLoading
                            ? null
                            : (formation) {
                                if (formation != null) {
                                  _changeFormation(formation);
                                }
                              },
                        items: _formations.map((option) {
                          final label = _formationLabel(option).toUpperCase();
                          return DropdownMenuItem(
                            value: option.formation,
                            child: Text(
                              label,
                              style: Body2_b.style
                                  .copyWith(color: colors.onSurface),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox.square(
                  key: ValueKey('analysis-best-eleven-loading'),
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_loadFailed)
            Row(
              key: const ValueKey('analysis-best-eleven-error'),
              children: [
                Expanded(
                  child: Text(
                    'Unable to load best eleven',
                    style: Body2.style,
                  ),
                ),
                TextButton(onPressed: _retryLoad, child: const Text('RETRY')),
              ],
            )
          else if (_lineup == null || _lineup!.players.isEmpty)
            Padding(
              key: const ValueKey('analysis-best-eleven-empty'),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No best eleven available',
                style: Body2.style,
              ),
            )
          else
            BestElevenPitch(players: _lineup!.players),
        ],
      ),
    );
  }
}
