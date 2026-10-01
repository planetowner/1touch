part of '../analysis.dart';

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
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'PROBABILITY'), style: Body2_b.style),
          const SizedBox(height: 16),
          if (_isLoading && _snapshot == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: FootballLoadingIndicator(
                  key: ValueKey('team-probability-loading'),
                ),
              ),
            )
          else if (_loadError != null && _snapshot == null)
            Center(
              child: TextButton(
                key: const ValueKey('team-probability-retry'),
                onPressed: _startLoad,
                child: Text(tr(context, 'Retry probability')),
              ),
            )
          else if (_snapshot case final snapshot?)
            LayoutBuilder(
              builder: (context, constraints) {
                // 345px content width: 165px card + 15px gap + 165px card.
                const gap = 15.0;
                final cardWidth = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  key: const ValueKey('team-probability-cards'),
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final card in snapshot.cards)
                      SizedBox(
                        width: cardWidth,
                        height: 165,
                        child: _probabilityBox(context, snapshot, card),
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
    TeamProbabilitySnapshot snapshot,
    TeamProbabilityCard card,
  ) {
    final delta = card.changePercentagePoints;
    final showDelta = delta != null && delta != 0;
    final isUp = delta != null && delta > 0;

    return Container(
      key: ValueKey('team-probability-surface-${card.event}'),
      decoration: BoxDecoration(
        color: AppColors.of(context).cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: appCardShadows(context),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('team-probability-card-${card.event}'),
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TeamProbabilityScreen(
                teamId: snapshot.teamId,
                event: card.event,
                initialSnapshot: snapshot,
                repository: widget.repository,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  key: ValueKey('team-probability-title-slot-${card.event}'),
                  width: double.infinity,
                  height: 39,
                  child: Text(
                    _eventTitle(card.event),
                    maxLines:
                        Localizations.localeOf(context).languageCode == 'ko'
                            ? 1
                            : 2,
                    softWrap:
                        Localizations.localeOf(context).languageCode != 'ko',
                    overflow: TextOverflow.ellipsis,
                    style: Body1.style.copyWith(height: 1.3),
                  ),
                ),
                SizedBox(
                  key: ValueKey('team-probability-footer-${card.event}'),
                  width: double.infinity,
                  height: 71,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: OverflowBox(
                          alignment: Alignment.bottomLeft,
                          minWidth: 0,
                          maxWidth: double.infinity,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${(card.probability * 100).round()}',
                                key: ValueKey(
                                  'team-probability-value-${card.event}',
                                ),
                                style: Heading1.style.copyWith(height: 0.9),
                              ),
                              Text(
                                '%',
                                key: ValueKey(
                                  'team-probability-percent-${card.event}',
                                ),
                                style: Heading4.style.copyWith(height: 1.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showDelta)
                        Align(
                          alignment: Alignment.topLeft,
                          child: Row(
                            key: ValueKey(
                              'team-probability-delta-row-${card.event}',
                            ),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                isUp
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                key: ValueKey(
                                  'team-probability-delta-icon-${card.event}',
                                ),
                                color: isUp
                                    ? const Color(0xFF36CC7A)
                                    : const Color(0xFFFF5C5C),
                                size: 24,
                              ),
                              Text(
                                '${_formatDelta(delta.abs())}%',
                                key: ValueKey(
                                  'team-probability-delta-${card.event}',
                                ),
                                style: Heading5.style.copyWith(height: 1.1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _eventTitle(String event) {
    return switch (event) {
      'league_winner' => tr(context, 'Chances to win\nLEAGUE Trophy'),
      'ucl_winner' => tr(context, 'Chances to win\nUCL Trophy'),
      'uel_winner' => tr(context, 'Chances to win\nUEL Trophy'),
      'uecl_winner' => tr(context, 'Chances to win\nUECL Trophy'),
      'top_4' => tr(context, 'Chances to finish\nTOP 4'),
      'top_6' => tr(context, 'Chances to finish\nTOP 6'),
      'direct_relegation' => tr(context, 'Chances of\nRELEGATION'),
      'relegation_playoff' => tr(context, 'Chances of\nRELEGATION PLAYOFF'),
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
