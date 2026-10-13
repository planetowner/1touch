import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/page_refresh.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/competitions/tournament_bracket_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class ApiKnockoutBracket extends StatefulWidget {
  const ApiKnockoutBracket({
    super.key,
    required this.competitionId,
    required this.seasonId,
    this.currentTeamId,
    this.repository,
    this.onInteractionChanged,
  });

  final int competitionId;
  final int seasonId;
  final int? currentTeamId;
  final TournamentBracketRepository? repository;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  State<ApiKnockoutBracket> createState() => _ApiKnockoutBracketState();
}

class _ApiKnockoutBracketState extends State<ApiKnockoutBracket>
    with PageRefreshParticipant<ApiKnockoutBracket> {
  late Future<TournamentBracket> _bracket;

  TournamentBracketRepository get _repository =>
      widget.repository ?? tournamentBracketRepository;

  @override
  Future<void> refreshPage() async {
    final request = _repository.refresh(widget.competitionId, widget.seasonId);
    setState(() {
      _bracket = request;
    });
    try {
      await request;
    } on Object {
      // 실패는 본문의 재시도로 안내하고, 기존 대진표는 유지해요.
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ApiKnockoutBracket oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.competitionId != widget.competitionId ||
        oldWidget.seasonId != widget.seasonId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    _bracket = _repository.load(widget.competitionId, widget.seasonId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) => FutureBuilder<TournamentBracket>(
        // FutureBuilder가 이전 시즌의 데이터를 새 시즌에 남기지 않게 해요.
        key: ValueKey((_repository, widget.competitionId, widget.seasonId)),
        future: _bracket,
        builder: (context, snapshot) {
          final bracket =
              _repository.cached(widget.competitionId, widget.seasonId) ??
                  snapshot.data;
          if (bracket == null && !snapshot.hasError) {
            return const Center(child: FootballLoadingIndicator());
          }
          if (bracket == null) {
            return Column(
              children: [
                Text(tr(context, 'Unable to load bracket.')),
                TextButton(
                  onPressed: () => setState(_load),
                  child: Text(tr(context, 'Retry')),
                ),
              ],
            );
          }

          if (bracket.status == 'not_published' || bracket.stages.isEmpty) {
            return Center(
              child: Text(tr(context, 'Bracket has not been published yet.')),
            );
          }

          return _TournamentBracketView(
            stages: bracket.stages,
            currentTeamId: widget.currentTeamId,
            onInteractionChanged: widget.onInteractionChanged,
          );
        },
      ),
    );
  }
}

class _TournamentBracketView extends StatefulWidget {
  const _TournamentBracketView({
    required this.stages,
    required this.currentTeamId,
    this.onInteractionChanged,
  });

  final List<BracketStage> stages;
  final int? currentTeamId;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  State<_TournamentBracketView> createState() => _TournamentBracketViewState();
}

class _TournamentBracketViewState extends State<_TournamentBracketView> {
  static const double _shadowInset = 16;
  static const double _maximumCardWidth = 165;
  static const double _cardHeight = 92;
  static const double _connectorWidth = 20;
  static const double _baseStep = 116;
  final ScrollController _roundController = ScrollController();
  int? _dragStartPage;

  @override
  void dispose() {
    _roundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('tournament-bracket'),
      padding: const EdgeInsets.symmetric(horizontal: 24 - _shadowInset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pairWidth = constraints.maxWidth - _shadowInset * 2;
          // 두 라운드 카드와 연결선이 한 화면에 들어오게 카드 폭을 정해요.
          // 한 라운드뿐이면 최대 카드 폭 안에서 카드 하나에 폭을 배분해요.
          final cardWidth = widget.stages.length == 1
              ? math.min(_maximumCardWidth, pairWidth)
              : math.min(
                  _maximumCardWidth,
                  (pairWidth - _connectorWidth) / 2,
                );
          final roundWidth = cardWidth + _connectorWidth;

          return AnimatedBuilder(
            animation: _roundController,
            builder: (context, _) {
              final maxPage = math.max(0, widget.stages.length - 2);
              final page = (_roundController.hasClients
                      ? _roundController.offset / roundWidth
                      : 0.0)
                  .clamp(0.0, maxPage.toDouble());
              final (verticalOffset, contentHeight) = _contentMetrics(page);

              return SizedBox(
                height: contentHeight + _shadowInset * 2,
                child: _BracketGestureGuard(
                  onInteractionChanged: widget.onInteractionChanged,
                  child: Padding(
                    key: const ValueKey('tournament-bracket-pages'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: _shadowInset),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (_) {
                        _dragStartPage = (_roundController.offset / roundWidth)
                            .round()
                            .clamp(0, maxPage);
                      },
                      onHorizontalDragUpdate: (details) {
                        final startPage = _dragStartPage;
                        if (startPage == null) return;
                        final minimum = math.max(0, startPage - 1) * roundWidth;
                        final maximum =
                            math.min(maxPage, startPage + 1) * roundWidth;
                        _roundController.jumpTo(
                          (_roundController.offset - details.delta.dx)
                              .clamp(minimum, maximum),
                        );
                      },
                      onHorizontalDragEnd: (details) => _finishRoundDrag(
                          roundWidth, maxPage,
                          velocity: details.primaryVelocity ?? 0),
                      onHorizontalDragCancel: () =>
                          _finishRoundDrag(roundWidth, maxPage),
                      child: SingleChildScrollView(
                        controller: _roundController,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: _shadowInset,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var index = 0;
                                  index < widget.stages.length;
                                  index++)
                                _buildStage(
                                  context,
                                  index,
                                  contentHeight,
                                  cardWidth,
                                  roundWidth,
                                  verticalOffset,
                                  page: page,
                                  hasNextStage:
                                      index < widget.stages.length - 1,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _finishRoundDrag(double roundWidth, int maxPage, {double velocity = 0}) {
    final startPage = _dragStartPage;
    if (startPage == null) return;
    _dragStartPage = null;
    final distance = _roundController.offset - startPage * roundWidth;
    // 빠른 스와이프는 속도 200, 느린 드래그는 한 라운드 폭의 1/3을
    // 넘었을 때만 이동하고 시작 페이지에서 한 단계 이상 건너뛰지 않아요.
    final direction = velocity.abs() > 200
        ? (velocity < 0 ? 1 : -1)
        : distance.abs() > roundWidth / 3
            ? (distance > 0 ? 1 : -1)
            : 0;
    final target = (startPage + direction).clamp(0, maxPage) * roundWidth;
    _roundController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Widget _buildStage(
    BuildContext context,
    int stageIndex,
    double contentHeight,
    double cardWidth,
    double roundWidth,
    double verticalOffset, {
    required double page,
    required bool hasNextStage,
  }) {
    final stage = widget.stages[stageIndex];
    final previousTiePositions = {
      if (stageIndex > 0)
        for (var i = 0; i < widget.stages[stageIndex - 1].ties.length; i++)
          widget.stages[stageIndex - 1].ties[i].id: i,
    };
    final destinations = {
      if (hasNextStage)
        for (var i = 0; i < widget.stages[stageIndex + 1].ties.length; i++)
          widget.stages[stageIndex + 1].ties[i].id: i,
    };

    return SizedBox(
      key: ValueKey('bracket-stage-${stage.name}'),
      width: hasNextStage ? roundWidth : cardWidth,
      height: contentHeight,
      child: Stack(
        children: [
          if (hasNextStage)
            Positioned.fill(
              child: CustomPaint(
                key: ValueKey('bracket-connectors-${stage.name}'),
                painter: _TournamentConnectorPainter(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppPalette.lightModeDarkGrey
                      : AppColors.of(context).mutedForeground,
                  // 추첨 전처럼 연결 정보가 없는 경기는 임의로 짝짓지 않아요.
                  connections: [
                    for (var i = 0; i < stage.ties.length; i++)
                      if (destinations[stage.ties[i].nextTieId]
                          case final int target)
                        (
                          sourceY: _cardTop(stageIndex, i, page) +
                              _cardHeight / 2 -
                              verticalOffset,
                          destinationY: _cardTop(stageIndex + 1, target, page) +
                              _cardHeight / 2 -
                              verticalOffset,
                        ),
                  ],
                  cardWidth: cardWidth,
                  roundWidth: roundWidth,
                ),
              ),
            ),
          for (var tieIndex = 0; tieIndex < stage.ties.length; tieIndex++)
            Positioned(
              left: 0,
              top: _cardTop(stageIndex, tieIndex, page) - verticalOffset,
              child: _TournamentMatchCard(
                tie: stage.ties[tieIndex],
                previousTiePositions: previousTiePositions,
                currentTeamId: widget.currentTeamId,
                width: cardWidth,
              ),
            ),
        ],
      ),
    );
  }

  double _cardTop(int stageIndex, int tieIndex, double page) {
    // 유럽대항전 플레이오프와 16강은 모두 8대진이에요. 실제 대진 수로 간격을 정해요.
    final first = page.floor();
    final count = widget.stages[first].ties.length;
    final nextCount = widget
        .stages[math.min(first + 1, widget.stages.length - 1)].ties.length;
    final visibleCount = count * math.pow(nextCount / count, page - first);
    final multiplier = visibleCount / widget.stages[stageIndex].ties.length;
    final center = _baseStep * (multiplier * tieIndex + multiplier / 2);
    return center - _cardHeight / 2;
  }

  (double, double) _contentMetrics(double page) {
    // 가로 스크롤 중 보이는 최대 세 라운드의 맨 위·맨 아래 카드로
    // 높이를 정해 빈 위쪽 공간 없이 대진표를 표시해요.
    final firstIndex = page.floor();
    final visibleIndexes = [
      for (var index = firstIndex;
          index < widget.stages.length && index <= firstIndex + 2;
          index++)
        index,
    ];
    final populatedIndexes = visibleIndexes
        .where((index) => widget.stages[index].ties.isNotEmpty)
        .toList(growable: false);
    if (populatedIndexes.isEmpty) return (0, _cardHeight);

    final verticalOffset = populatedIndexes
        .map((index) => _cardTop(index, 0, page))
        .reduce(math.min);
    final contentBottom = populatedIndexes.map((index) {
      final ties = widget.stages[index].ties;
      return _cardTop(index, ties.length - 1, page) + _cardHeight;
    }).reduce(math.max);
    return (
      verticalOffset,
      math.max(_cardHeight, contentBottom - verticalOffset)
    );
  }
}

class _BracketGestureGuard extends StatefulWidget {
  const _BracketGestureGuard({
    required this.child,
    this.onInteractionChanged,
  });

  final Widget child;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  State<_BracketGestureGuard> createState() => _BracketGestureGuardState();
}

class _BracketGestureGuardState extends State<_BracketGestureGuard> {
  final Set<int> _activePointers = <int>{};

  void _start(PointerDownEvent event) {
    final wasEmpty = _activePointers.isEmpty;
    _activePointers.add(event.pointer);
    if (wasEmpty) widget.onInteractionChanged?.call(true);
  }

  void _finish(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) widget.onInteractionChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _start,
      onPointerUp: _finish,
      onPointerCancel: _finish,
      child: widget.child,
    );
  }
}

class _TournamentMatchCard extends StatelessWidget {
  const _TournamentMatchCard({
    required this.tie,
    required this.previousTiePositions,
    required this.currentTeamId,
    required this.width,
  });

  final BracketTie tie;
  final Map<String, int> previousTiePositions;
  final int? currentTeamId;
  final double width;

  @override
  Widget build(BuildContext context) {
    final detailMatch = tie.matches.cast<BracketMatch?>().firstWhere(
          (match) => match?.detailAvailable ?? false,
          orElse: () => null,
        );
    final scores = _scoresFor(tie);
    // 1차전 홈·원정 순서와 진출 경로는 다를 수 있어요. 팀과 점수를 함께 옮겨요.
    final rows = List.generate(
      2,
      (index) => (
        slot: index < tie.slots.length ? tie.slots[index] : null,
        score: index == 0 ? scores.$1 : scores.$2,
      ),
    )..sort((a, b) {
        final first = previousTiePositions[a.slot?.sourceTieId];
        final second = previousTiePositions[b.slot?.sourceTieId];
        return first != null && second != null ? first.compareTo(second) : 0;
      });

    return Semantics(
      button: detailMatch != null,
      child: GestureDetector(
        key: ValueKey('bracket-tie-${tie.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: detailMatch == null
            ? null
            : () => context.push(_matchRoute(detailMatch)),
        child: Container(
          key: ValueKey('bracket-match-card-${tie.id}'),
          width: width,
          padding: EdgeInsets.symmetric(
            horizontal: width < 155 ? 18 : 24,
            vertical: 16,
          ),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF272828)
                : AppColors.of(context).cardBackground,
            borderRadius: BorderRadius.circular(8),
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                _TournamentTeamRow(
                  slot: rows[index].slot,
                  score: rows[index].score,
                  highlighted: rows[index].slot != null &&
                      rows[index].slot!.teamId == currentTeamId,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _matchRoute(BracketMatch match) {
    final normalizedStatus = match.status.trim().toUpperCase();
    final status = switch (normalizedStatus) {
      'FT' || 'AET' || 'PEN' || 'AWARDED' || 'WO' => 'past',
      'LIVE' ||
      '1H' ||
      'HT' ||
      '2H' ||
      'ET' ||
      'BT' ||
      'BREAK' ||
      'INT' =>
        'live',
      _ => 'upcoming',
    };
    return Uri(
      path: '/match/${match.id}',
      queryParameters: {'status': status},
    ).toString();
  }

  (String, String) _scoresFor(BracketTie value) {
    final aggregate = value.aggregateScore;
    if (aggregate != null && aggregate.length >= 2) {
      return ('${aggregate[0]}', '${aggregate[1]}');
    }
    if (value.matches.length == 1) {
      final match = value.matches.single;
      return ('${match.homeScore ?? '—'}', '${match.awayScore ?? '—'}');
    }
    return ('—', '—');
  }
}

class _TournamentTeamRow extends StatelessWidget {
  const _TournamentTeamRow({
    required this.slot,
    required this.score,
    required this.highlighted,
  });

  final BracketSlot? slot;
  final String score;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final teamId = slot?.teamId;
    final team = teamId == null ? null : teamRepository.findById(teamId);
    final textStyle = Body1.style.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
      height: 1.3,
    );

    return SizedBox(
      height: 24,
      child: Row(
        children: [
          if (teamId == null)
            Icon(
              Icons.shield_outlined,
              key: const ValueKey('bracket-team-placeholder'),
              size: 24,
              color: AppColors.of(context).mutedForeground,
            )
          else if (team?.imagePath != null && team!.imagePath!.isNotEmpty)
            Image.network(
              team.imagePath!,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => teamLogoFallback(teamId, size: 24),
            )
          else
            teamLogoFallback(teamId, size: 24),
          const SizedBox(width: 12),
          SizedBox(
            width: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _shortCode(context, teamId, slot?.label),
                maxLines: 1,
                style: textStyle,
              ),
            ),
          ),
          const Spacer(),
          Text(score, textAlign: TextAlign.right, style: textStyle),
        ],
      ),
    );
  }

  String _shortCode(BuildContext context, int? teamId, String? label) {
    final configured = teamId == null
        ? null
        : teamRepository.findById(teamId)?.shortCode?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured.toUpperCase();
    }

    final name = teamNameLabel(context, teamId, label ?? 'TBD').trim();
    final words = name
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length > 1) {
      return words.take(3).map((word) => word[0]).join().toUpperCase();
    }
    return name.substring(0, math.min(3, name.length)).toUpperCase();
  }
}

class _TournamentConnectorPainter extends CustomPainter {
  const _TournamentConnectorPainter({
    required this.color,
    required this.connections,
    required this.cardWidth,
    required this.roundWidth,
  });

  final Color color;
  final List<({double sourceY, double destinationY})> connections;
  final double cardWidth;
  final double roundWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final middleX = cardWidth + (roundWidth - cardWidth) / 2;
    for (final connection in connections) {
      canvas
        ..drawLine(
          Offset(cardWidth, connection.sourceY),
          Offset(middleX, connection.sourceY),
          paint,
        )
        ..drawLine(
          Offset(middleX, connection.sourceY),
          Offset(middleX, connection.destinationY),
          paint,
        )
        ..drawLine(
          Offset(middleX, connection.destinationY),
          Offset(roundWidth, connection.destinationY),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _TournamentConnectorPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.connections != connections ||
        oldDelegate.cardWidth != cardWidth ||
        oldDelegate.roundWidth != roundWidth;
  }
}
