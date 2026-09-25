import 'dart:math' as math;

import 'package:flutter/material.dart';
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
          return const Center(child: CircularProgressIndicator());
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

class _TournamentBracketView extends StatelessWidget {
  static const double _cardWidth = 165;
  static const double _cardHeight = 92;
  static const double _connectorWidth = 20;
  static const double _roundWidth = _cardWidth + _connectorWidth;
  static const double _baseStep = 116;

  const _TournamentBracketView({
    required this.stages,
    required this.currentTeamId,
    this.onInteractionChanged,
  });

  final List<BracketStage> stages;
  final int? currentTeamId;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  Widget build(BuildContext context) {
    final bracketUnits = <int>[
      for (var index = 0; index < stages.length; index++)
        stages[index].ties.length * math.pow(2, index).toInt(),
    ];
    final bracketHeight =
        _baseStep * math.max(1, bracketUnits.reduce(math.max)).toDouble();
    final bracketWidth = _roundWidth * (stages.length - 1) + _cardWidth;
    final maximumViewportHeight =
        (MediaQuery.sizeOf(context).height * 0.62).clamp(320.0, 620.0);
    final viewportHeight = math.min(bracketHeight, maximumViewportHeight);

    return Padding(
      key: const ValueKey('tournament-bracket'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: viewportHeight,
        width: double.infinity,
        child: _BracketGestureGuard(
          onInteractionChanged: onInteractionChanged,
          child: InteractiveViewer(
            key: const ValueKey('tournament-bracket-zoom'),
            constrained: false,
            minScale: 0.5,
            maxScale: 1.5,
            alignment: Alignment.topLeft,
            boundaryMargin: const EdgeInsets.all(48),
            child: SizedBox(
              width: bracketWidth,
              height: bracketHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var stageIndex = 0;
                      stageIndex < stages.length;
                      stageIndex++)
                    _buildStage(context, stageIndex, bracketHeight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage(
    BuildContext context,
    int stageIndex,
    double bracketHeight,
  ) {
    final stage = stages[stageIndex];
    final hasNextStage = stageIndex < stages.length - 1;

    return SizedBox(
      key: ValueKey('bracket-stage-${stage.name}'),
      width: hasNextStage ? _roundWidth : _cardWidth,
      height: bracketHeight,
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
                  destinationCount: stages[stageIndex + 1].ties.length,
                  stageIndex: stageIndex,
                  cardWidth: _cardWidth,
                  roundWidth: _roundWidth,
                  baseStep: _baseStep,
                ),
              ),
            ),
          for (var tieIndex = 0; tieIndex < stage.ties.length; tieIndex++)
            Positioned(
              left: 0,
              top: _cardTop(stageIndex, tieIndex),
              child: _TournamentMatchCard(
                tie: stage.ties[tieIndex],
                currentTeamId: currentTeamId,
              ),
            ),
        ],
      ),
    );
  }

  double _cardTop(int stageIndex, int tieIndex) {
    final multiplier = math.pow(2, stageIndex).toDouble();
    final center = _baseStep * (multiplier * tieIndex + multiplier / 2);
    return center - _cardHeight / 2;
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
  static const double _width = 165;

  const _TournamentMatchCard({
    required this.tie,
    required this.currentTeamId,
  });

  final BracketTie tie;
  final int? currentTeamId;

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
          width: _width,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
  });

  final Color color;
  final int sourceCount;
  final int destinationCount;
  final int stageIndex;
  final double cardWidth;
  final double roundWidth;
  final double baseStep;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final middleX = cardWidth + (roundWidth - cardWidth) / 2;
    final pairCount = math.min(destinationCount, sourceCount ~/ 2);

    for (var pairIndex = 0; pairIndex < pairCount; pairIndex++) {
      final firstCenter = _centerFor(stageIndex, pairIndex * 2);
      final secondCenter = _centerFor(stageIndex, pairIndex * 2 + 1);
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

  double _centerFor(int index, int tieIndex) {
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
        oldDelegate.baseStep != baseStep;
  }
}
