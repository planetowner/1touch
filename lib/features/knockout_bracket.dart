import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';

enum KnockoutRound { roundOf16, quarterFinal, semiFinal, finalRound }

KnockoutRound? knockoutRoundFromName(String? raw) {
  if (raw == null) return null;
  final normalized = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return switch (normalized) {
    'R16' || 'RO16' || 'ROUND16' || 'LAST16' => KnockoutRound.roundOf16,
    'QF' || 'QUARTERFINAL' || 'QUARTERFINALS' => KnockoutRound.quarterFinal,
    'SF' || 'SEMIFINAL' || 'SEMIFINALS' => KnockoutRound.semiFinal,
    'F' || 'FINAL' => KnockoutRound.finalRound,
    _ => null,
  };
}

bool hasEuropeanKnockoutStage(Iterable<Fixture> fixtures) {
  return fixtures.any(
    (fixture) =>
        fixture.competitionType == CompetitionType.europe &&
        knockoutRoundFromName(fixture.roundName) != null,
  );
}

class KnockoutBracket extends StatelessWidget {
  static const double _cardWidth = 180;
  static const double _cardHeight = 92;
  static const double _roundGap = 44;
  static const double _roundWidth = _cardWidth + _roundGap;
  static const double _baseStep = 112;
  static const double _bracketHeight = _baseStep * 8;

  final List<Fixture> fixtures;
  final int? currentTeamId;

  const KnockoutBracket({
    super.key,
    required this.fixtures,
    required this.currentTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = <_RoundColumnData>[
      _RoundColumnData(
        expectedMatches: 8,
        fixtures: _fixturesFor(KnockoutRound.roundOf16),
      ),
      _RoundColumnData(
        expectedMatches: 4,
        fixtures: _fixturesFor(KnockoutRound.quarterFinal),
      ),
      _RoundColumnData(
        expectedMatches: 2,
        fixtures: _fixturesFor(KnockoutRound.semiFinal),
      ),
      _RoundColumnData(
        expectedMatches: 1,
        fixtures: _fixturesFor(KnockoutRound.finalRound),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _bracketHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < rounds.length; index++)
                  _buildRoundSegment(
                    context: context,
                    roundIndex: index,
                    data: rounds[index],
                    drawConnectors: index < rounds.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Fixture> _fixturesFor(KnockoutRound round) {
    final matches = fixtures
        .where((fixture) => knockoutRoundFromName(fixture.roundName) == round)
        .toList()
      ..sort((a, b) => a.startingAt.compareTo(b.startingAt));
    return matches;
  }

  Widget _buildRoundSegment({
    required BuildContext context,
    required int roundIndex,
    required _RoundColumnData data,
    required bool drawConnectors,
  }) {
    final width = drawConnectors ? _roundWidth : _cardWidth;
    return SizedBox(
      width: width,
      height: _bracketHeight,
      child: Stack(
        children: [
          if (drawConnectors)
            Positioned.fill(
              child: CustomPaint(
                painter: _BracketConnectorPainter(
                  color: AppColors.of(context).mutedForeground,
                  roundIndex: roundIndex,
                  cardWidth: _cardWidth,
                  roundWidth: _roundWidth,
                  baseStep: _baseStep,
                ),
              ),
            ),
          for (var index = 0; index < data.expectedMatches; index++)
            Positioned(
              left: 0,
              top: _cardTop(roundIndex, index),
              child: _BracketMatchCard(
                fixture:
                    index < data.fixtures.length ? data.fixtures[index] : null,
                currentTeamId: currentTeamId,
              ),
            ),
        ],
      ),
    );
  }

  double _cardTop(int roundIndex, int matchIndex) {
    final multiplier = math.pow(2, roundIndex).toDouble();
    final center = _baseStep * (multiplier * matchIndex + multiplier / 2);
    return center - _cardHeight / 2;
  }
}

class _RoundColumnData {
  final int expectedMatches;
  final List<Fixture> fixtures;

  const _RoundColumnData({
    required this.expectedMatches,
    required this.fixtures,
  });
}

class _BracketMatchCard extends StatelessWidget {
  static const double _width = 180;
  static const double _height = 92;

  final Fixture? fixture;
  final int? currentTeamId;

  const _BracketMatchCard({
    required this.fixture,
    required this.currentTeamId,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final match = fixture;
    final isCurrentTeamMatch = match != null &&
        currentTeamId != null &&
        (match.homeTeamId == currentTeamId ||
            match.awayTeamId == currentTeamId);

    return GestureDetector(
      onTap: match == null
          ? null
          : () => context.push(
                '/match/${match.fixtureId}?status=${match.status.name}',
              ),
      child: Container(
        width: _width,
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: appColors.subtleBackground,
          borderRadius: BorderRadius.circular(8),
          border:
              isCurrentTeamMatch ? Border.all(color: appColors.divider) : null,
        ),
        child: match == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BracketTeamRow.placeholder(),
                  _BracketTeamRow.placeholder(),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BracketTeamRow(
                    team: teamRepository.findByIdOrUnknown(match.homeTeamId),
                    score: _scoreFor(match, isHome: true),
                    highlighted: match.homeTeamId == currentTeamId,
                  ),
                  _BracketTeamRow(
                    team: teamRepository.findByIdOrUnknown(match.awayTeamId),
                    score: _scoreFor(match, isHome: false),
                    highlighted: match.awayTeamId == currentTeamId,
                  ),
                ],
              ),
      ),
    );
  }

  static String _scoreFor(Fixture fixture, {required bool isHome}) {
    final score = isHome ? fixture.homeScore : fixture.awayScore;
    final penalties =
        isHome ? fixture.homePenaltyScore : fixture.awayPenaltyScore;
    if (score == null) return '-';
    return penalties == null ? '$score' : '$score ($penalties)';
  }
}

class _BracketTeamRow extends StatelessWidget {
  final Team? team;
  final String score;
  final bool highlighted;

  const _BracketTeamRow({
    required this.team,
    required this.score,
    required this.highlighted,
  });

  const _BracketTeamRow.placeholder()
      : team = null,
        score = '-',
        highlighted = false;

  @override
  Widget build(BuildContext context) {
    final value = team;
    final appColors = AppColors.of(context);
    final textStyle = Body2.style.copyWith(
      color: value == null
          ? appColors.mutedForeground
          : Theme.of(context).colorScheme.onSurface,
      fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
    );

    return Row(
      children: [
        if (value == null)
          Icon(
            Icons.shield_outlined,
            color: appColors.mutedForeground,
            size: 24,
          )
        else if (value.imagePath != null && value.imagePath!.isNotEmpty)
          Image.network(
            value.imagePath!,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                teamLogoFallback(value.teamId, size: 24),
          )
        else
          teamLogoFallback(value.teamId, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value?.shortCode ?? value?.name ?? 'TBD',
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(score, style: textStyle),
      ],
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  final Color color;
  final int roundIndex;
  final double cardWidth;
  final double roundWidth;
  final double baseStep;

  const _BracketConnectorPainter({
    required this.color,
    required this.roundIndex,
    required this.cardWidth,
    required this.roundWidth,
    required this.baseStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final pairCount = 4 >> roundIndex;
    final middleX = cardWidth + (roundWidth - cardWidth) / 2;

    for (var pairIndex = 0; pairIndex < pairCount; pairIndex++) {
      final firstCenter = _centerFor(roundIndex, pairIndex * 2);
      final secondCenter = _centerFor(roundIndex, pairIndex * 2 + 1);
      final nextCenter = (firstCenter + secondCenter) / 2;

      canvas.drawLine(
        Offset(cardWidth, firstCenter),
        Offset(middleX, firstCenter),
        paint,
      );
      canvas.drawLine(
        Offset(cardWidth, secondCenter),
        Offset(middleX, secondCenter),
        paint,
      );
      canvas.drawLine(
        Offset(middleX, firstCenter),
        Offset(middleX, secondCenter),
        paint,
      );
      canvas.drawLine(
        Offset(middleX, nextCenter),
        Offset(roundWidth, nextCenter),
        paint,
      );
    }
  }

  double _centerFor(int index, int matchIndex) {
    final multiplier = math.pow(2, index).toDouble();
    return baseStep * (multiplier * matchIndex + multiplier / 2);
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.roundIndex != roundIndex ||
        oldDelegate.cardWidth != cardWidth ||
        oldDelegate.roundWidth != roundWidth ||
        oldDelegate.baseStep != baseStep;
  }
}
