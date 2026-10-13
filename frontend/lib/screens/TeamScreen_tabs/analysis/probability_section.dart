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

class _ProbabilitySectionState extends State<ProbabilitySection>
    with PageRefreshParticipant<ProbabilitySection> {
  @override
  Future<void> refreshPage() async {
    final teamId = widget.teamId;
    if (teamId == null) return;
    await _load(teamId, ++_requestId, _repository, forceRefresh: true);
  }

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
    TeamProbabilityRepository repository, {
    bool forceRefresh = false,
  }) async {
    try {
      final snapshot =
          await repository.loadForTeam(teamId, forceRefresh: forceRefresh);
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
        if (_snapshot == null) _loadError = error;
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
                final titleWidth = math.max(1.0, cardWidth - 68);
                final titleStyle = Body1.style.copyWith(height: 1.3);
                // 가장 긴 번역을 기준으로 같은 줄의 카드 높이를 맞춰요.
                final titleHeight =
                    snapshot.cards.fold<double>(60, (maxHeight, card) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: tr(context, probabilityEventTitle(card.event))
                          .replaceAll('\n', ' '),
                      style: titleStyle,
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    locale: Localizations.localeOf(context),
                  )..layout(maxWidth: titleWidth);
                  final height = painter.height.ceilToDouble();
                  painter.dispose();
                  return math.max(maxHeight, height);
                });
                final cardHeight = math.max(165.0, titleHeight + 105);
                return Wrap(
                  key: const ValueKey('team-probability-cards'),
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final card in snapshot.cards)
                      SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: _probabilityBox(
                          context,
                          snapshot,
                          card,
                          titleHeight: titleHeight,
                        ),
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
    TeamProbabilityCard card, {
    required double titleHeight,
  }) {
    final title =
        tr(context, probabilityEventTitle(card.event)).replaceAll('\n', ' ');
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
          onTap: card.event == 'relegation_playoff'
              ? null
              : () => Navigator.of(context).push(
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
                  height: titleHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: titleHeight,
                          child: Text(
                            title,
                            softWrap: true,
                            style: Body1.style.copyWith(height: 1.3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SvgPicture.asset(
                        'assets/expand_circle_right.svg',
                        key: ValueKey('team-probability-expand-${card.event}'),
                        width: 32,
                        height: 32,
                        colorFilter:
                            Theme.of(context).brightness == Brightness.light
                                ? const ColorFilter.mode(
                                    Color(0xFF0A0A0A), BlendMode.srcIn)
                                : null,
                      ),
                    ],
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
