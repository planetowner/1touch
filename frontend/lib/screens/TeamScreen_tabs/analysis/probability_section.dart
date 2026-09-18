part of '../Analysis.dart';

class ProbabilitySection extends StatefulWidget {
  const ProbabilitySection({
    super.key,
    required this.teamId,
    this.repository,
  });

  final int? teamId;
  final TeamProbabilityRepository? repository;

  @override
  State<ProbabilitySection> createState() => _ProbabilitySectionState();
}

class _ProbabilitySectionState extends State<ProbabilitySection> {
  TeamProbabilitySnapshot? _snapshot;
  bool _isLoading = false;
  bool _isUnavailable = false;
  Object? _loadError;
  int _requestId = 0;

  TeamProbabilityRepository get _repository =>
      widget.repository ?? teamProbabilityRepository;

  @override
  void initState() {
    super.initState();
    _startLoad(updateState: false);
  }

  @override
  void didUpdateWidget(covariant ProbabilitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.repository != widget.repository) {
      _startLoad();
    }
  }

  void _startLoad({bool updateState = true}) {
    final teamId = widget.teamId;
    final requestId = ++_requestId;
    TeamProbabilityRepository? repository;
    TeamProbabilitySnapshot? cached;
    Object? repositoryError;
    if (teamId != null) {
      try {
        repository = _repository;
        cached = repository.cachedForTeam(teamId);
      } on Object catch (error) {
        repositoryError = error;
      }
    }

    void prepare() {
      _snapshot = cached;
      _isLoading = teamId != null && cached == null && repositoryError == null;
      _isUnavailable = teamId == null || cached?.cards.isEmpty == true;
      _loadError = repositoryError;
    }

    if (updateState) {
      setState(prepare);
    } else {
      prepare();
    }

    if (teamId != null && repository != null) {
      unawaited(_load(teamId, requestId, repository));
    }
  }

  Future<void> _load(
    int teamId,
    int requestId,
    TeamProbabilityRepository repository,
  ) async {
    try {
      final snapshot = await repository.loadForTeam(teamId);
      if (!mounted || requestId != _requestId || teamId != widget.teamId) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
        _isUnavailable = snapshot.cards.isEmpty;
        _loadError = null;
      });
    } on TeamFeatureUnavailableException {
      if (!mounted || requestId != _requestId || teamId != widget.teamId) {
        return;
      }
      setState(() {
        _snapshot = null;
        _isLoading = false;
        _isUnavailable = true;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted || requestId != _requestId || teamId != widget.teamId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnavailable) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('team-probability-section'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROBABILITY', style: Body2_b.style),
          const SizedBox(height: 16),
          if (_isLoading && _snapshot == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  key: ValueKey('team-probability-loading'),
                ),
              ),
            )
          else if (_loadError != null && _snapshot == null)
            Center(
              child: TextButton(
                key: const ValueKey('team-probability-retry'),
                onPressed: _startLoad,
                child: const Text('Retry probability'),
              ),
            )
          else if (_snapshot case final snapshot?)
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 16.0;
                final cardWidth = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  key: const ValueKey('team-probability-cards'),
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final card in snapshot.cards)
                      SizedBox(
                        width: cardWidth,
                        child: _probabilityBox(context, card),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _probabilityBox(
    BuildContext context,
    TeamProbabilityCard card,
  ) {
    final delta = card.changePercentagePoints;
    final showDelta = delta != null && delta != 0;
    final isUp = delta != null && delta > 0;

    return Container(
      key: ValueKey('team-probability-card-${card.event}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_eventTitle(card.event), style: Body1.style),
          const SizedBox(height: 36),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${(card.probability * 100).round()}',
                        key: ValueKey(
                          'team-probability-value-${card.event}',
                        ),
                        style: Heading1.style,
                      ),
                      Text('%', style: Heading4.style),
                    ],
                  ),
                ),
              ),
              if (showDelta) ...[
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        Icon(
                          isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          key: ValueKey(
                            'team-probability-delta-icon-${card.event}',
                          ),
                          color: isUp ? Colors.blueAccent : Colors.redAccent,
                          size: 24,
                        ),
                        Text(
                          _formatDelta(delta.abs()),
                          key: ValueKey(
                            'team-probability-delta-${card.event}',
                          ),
                          style: Heading5.style,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _eventTitle(String event) {
    return switch (event) {
      'league_winner' => 'Chances to win\nLEAGUE Trophy',
      'top_4' => 'Chances to finish\nTOP 4',
      'top_6' => 'Chances to finish\nTOP 6',
      'direct_relegation' => 'Chances of\nDIRECT RELEGATION',
      'relegation_playoff' => 'Chances of\nRELEGATION PLAYOFF',
      _ => event
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
    };
  }

  String _formatDelta(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
