import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
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

class _ApiKnockoutBracketState extends State<ApiKnockoutBracket> {
  late Future<TournamentBracket> _bracket;

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

  void _load() => _bracket = (widget.repository ?? tournamentBracketRepository)
      .load(widget.competitionId, widget.seasonId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TournamentBracket>(
      future: _bracket,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FootballLoadingIndicator());
        }
        if (snapshot.hasError) {
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

        final bracket = snapshot.requireData;
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
                                  layoutStageIndex: index - page,
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
    required double layoutStageIndex,
    required bool hasNextStage,
  }) {
    final stage = widget.stages[stageIndex];

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
                  sourceCount: stage.ties.length,
                  destinationCount: widget.stages[stageIndex + 1].ties.length,
                  stageIndex: layoutStageIndex,
                  cardWidth: cardWidth,
                  roundWidth: roundWidth,
                  baseStep: _baseStep,
                  verticalOffset: verticalOffset,
                ),
              ),
            ),
          for (var tieIndex = 0; tieIndex < stage.ties.length; tieIndex++)
            Positioned(
              left: 0,
              top: _cardTop(layoutStageIndex, tieIndex) - verticalOffset,
              child: _TournamentMatchCard(
                tie: stage.ties[tieIndex],
                currentTeamId: widget.currentTeamId,
                width: cardWidth,
              ),
            ),
        ],
      ),
    );
  }

  double _cardTop(double stageIndex, int tieIndex) {
    // 다음 라운드의 한 카드는 이전 라운드 두 카드의 중심 사이에 놓여요.
    // 단계마다 중심 간격을 두 배로 늘려 연결선 끝과 카드 중심을 맞춰요.
    final multiplier = math.pow(2, stageIndex).toDouble();
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
        .map((index) => _cardTop(index - page, 0))
        .reduce(math.min);
    final contentBottom = populatedIndexes.map((index) {
      final ties = widget.stages[index].ties;
      return _cardTop(index - page, ties.length - 1) + _cardHeight;
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
    required this.currentTeamId,
    required this.width,
  });

  final BracketTie tie;
  final int? currentTeamId;
  final double width;

  @override
  Widget build(BuildContext context) {
    final detailMatch = tie.matches.cast<BracketMatch?>().firstWhere(
          (match) => match?.detailAvailable ?? false,
          orElse: () => null,
        );
    final scores = _scoresFor(tie);

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
              _TournamentTeamRow(
                slot: tie.slots.isNotEmpty ? tie.slots[0] : null,
                score: scores.$1,
                highlighted: tie.slots.isNotEmpty &&
                    tie.slots[0].teamId == currentTeamId,
              ),
              const SizedBox(height: 12),
              _TournamentTeamRow(
                slot: tie.slots.length > 1 ? tie.slots[1] : null,
                score: scores.$2,
                highlighted: tie.slots.length > 1 &&
                    tie.slots[1].teamId == currentTeamId,
              ),
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
    required this.sourceCount,
    required this.destinationCount,
    required this.stageIndex,
    required this.cardWidth,
    required this.roundWidth,
    required this.baseStep,
    required this.verticalOffset,
  });

  final Color color;
  final int sourceCount;
  final int destinationCount;
  final double stageIndex;
  final double cardWidth;
  final double roundWidth;
  final double baseStep;
  final double verticalOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final middleX = cardWidth + (roundWidth - cardWidth) / 2;
    final pairCount = math.min(destinationCount, sourceCount ~/ 2);

    for (var pairIndex = 0; pairIndex < pairCount; pairIndex++) {
      final firstCenter =
          _centerFor(stageIndex, pairIndex * 2) - verticalOffset;
      final secondCenter =
          _centerFor(stageIndex, pairIndex * 2 + 1) - verticalOffset;
      final destinationCenter = (firstCenter + secondCenter) / 2;

      canvas
        ..drawLine(
          Offset(cardWidth, firstCenter),
          Offset(middleX, firstCenter),
          paint,
        )
        ..drawLine(
          Offset(cardWidth, secondCenter),
          Offset(middleX, secondCenter),
          paint,
        )
        ..drawLine(
          Offset(middleX, firstCenter),
          Offset(middleX, secondCenter),
          paint,
        )
        ..drawLine(
          Offset(middleX, destinationCenter),
          Offset(roundWidth, destinationCenter),
          paint,
        );
    }
  }

  double _centerFor(double index, int tieIndex) {
    final multiplier = math.pow(2, index).toDouble();
    return baseStep * (multiplier * tieIndex + multiplier / 2);
  }

  @override
  bool shouldRepaint(covariant _TournamentConnectorPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.sourceCount != sourceCount ||
        oldDelegate.destinationCount != destinationCount ||
        oldDelegate.stageIndex != stageIndex ||
        oldDelegate.cardWidth != cardWidth ||
        oldDelegate.roundWidth != roundWidth ||
        oldDelegate.baseStep != baseStep ||
        oldDelegate.verticalOffset != verticalOffset;
  }
}
