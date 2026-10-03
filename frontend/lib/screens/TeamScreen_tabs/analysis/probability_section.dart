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
          Text(trUpper(context, 'Probability'), style: Body2_b.style),
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    // 좁은 화면에서도 두 번째 줄의 대회·목표 이름이 사라지지 않게 해요.
                    child: Text(
                      tr(context, probabilityEventTitle(card.event)),
                      maxLines:
                          Localizations.localeOf(context).languageCode == 'ko'
                              ? 1
                              : 2,
                      softWrap: false,
                      style: Body1.style.copyWith(height: 1.3),
                    ),
                  ),
                ),
                SizedBox(
                  key: ValueKey('team-probability-footer-${card.event}'),
                  width: double.infinity,
                  height: 71,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      alignment: Alignment.bottomLeft,
                      fit: BoxFit.scaleDown,
                      child: ProbabilityNumber(
                        card: card,
                        keyPrefix: 'team-probability',
                        keySuffix: '-${card.event}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
