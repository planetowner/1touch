import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/l10n/app_localizations.dart';

List<Color> resolveBettingBarColors({
  required Team homeTeam,
  required Team awayTeam,
  required Color background,
  int? anchorTeamId,
}) {
  final anchorIsAway = anchorTeamId == awayTeam.teamId;
  final anchorTeam = anchorIsAway ? awayTeam : homeTeam;
  final opponentTeam = anchorIsAway ? homeTeam : awayTeam;
  final comparisonColors = TeamComparisonColorResolver.resolve(
    anchorTeamName: anchorTeam.name,
    anchorPrimaryFallback: Color(anchorTeam.primaryColor),
    opponentTeamName: opponentTeam.name,
    opponentPrimaryFallback: Color(opponentTeam.primaryColor),
    background: background,
  );
  final homeColor =
      anchorIsAway ? comparisonColors.opponent : comparisonColors.anchor;
  final awayColor =
      anchorIsAway ? comparisonColors.anchor : comparisonColors.opponent;
  return [homeColor, Color.lerp(homeColor, awayColor, 0.5)!, awayColor];
}

class MatchBettingSection extends StatelessWidget {
  const MatchBettingSection({
    super.key,
    required this.controller,
    required this.homeTeam,
    required this.awayTeam,
    this.anchorTeamId,
  });
  final BettingController controller;
  final Team homeTeam;
  final Team awayTeam;
  final int? anchorTeamId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final market = controller.market;
          final bet = market?.bet;
          if (market?.unavailableReason == 'betting_not_open') {
            return Container(
              key: const ValueKey('match-betting-opening-notice'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.of(context).cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: appCardShadows(context),
              ),
              child: Text(
                tr(context, 'Betting opens {date}.', {
                  'date': fixtureDateLabel(market!.opensAt!,
                          locale: Localizations.localeOf(context))
                      .replaceAll('\n', ' '),
                }),
                style: Body1.style,
                textAlign: TextAlign.center,
              ),
            );
          }
          return Container(
            key: const ValueKey('match-betting-card'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: appCardShadows(context),
            ),
            child: Column(
              children: [
                if (market?.available == true)
                  MatchStatsHeader(
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    options: market!.options,
                    anchorTeamId: anchorTeamId,
                  ),
                if (market == null && controller.loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: FootballLoadingIndicator()),
                  ),
                if (market != null &&
                    (!market.canBet || !controller.beforeKickoff))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        tr(context, _unavailable(market.unavailableReason))),
                  ),
                if (market != null) ...[
                  const SizedBox(height: 20),
                  Text(tr(context, "You’ve got {points} pts!",
                      {'points': market.wallet.balance})),
                ],
                if (bet != null)
                  _BetReceipt(
                    bet: bet,
                    label: _label(context, bet.outcome, homeTeam, awayTeam),
                  ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(tr(context, controller.error!),
                      textAlign: TextAlign.center),
                  TextButton(
                    onPressed: controller.load,
                    child: Text(tr(context, 'RETRY')),
                  ),
                ],
                if (controller.canBet) ...[
                  const SizedBox(height: 20),
                  _BetButton(
                    text: bet?.isOpen == true
                        ? tr(context, 'EDIT BET')
                        : tr(context, 'PLACE A BET'),
                    onPressed: controller.spendingLimit < market!.stakeUnit
                        ? null
                        : () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BettingFlowModal(
                                controller: controller,
                                homeTeam: homeTeam,
                                awayTeam: awayTeam,
                                anchorTeamId: anchorTeamId,
                              ),
                            ),
                  ),
                  if (controller.spendingLimit < market.stakeUnit)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(tr(
                          context,
                          'You need at least {points} pts to place a bet.',
                          {'points': market.stakeUnit})),
                    ),
                ],
                if (controller.canCancel)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(tr(context, 'Cancel your bet?')),
                          content: Text(tr(
                              context,
                              '{points} pts will be returned.',
                              {'points': bet!.stake})),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(tr(context, 'KEEP BET')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(tr(context, 'CANCEL BET')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await controller.cancel();
                    },
                    child: Text(tr(context, 'CANCEL BET')),
                  ),
                if (controller.saving) const LinearProgressIndicator(),
              ],
            ),
          );
        },
      );
}

class BettingFlowModal extends StatefulWidget {
  const BettingFlowModal({
    super.key,
    required this.controller,
    required this.homeTeam,
    required this.awayTeam,
    this.anchorTeamId,
  });
  final BettingController controller;
  final Team homeTeam;
  final Team awayTeam;
  final int? anchorTeamId;
  @override
  State<BettingFlowModal> createState() => _BettingFlowModalState();
}

class _BettingFlowModalState extends State<BettingFlowModal> {
  BetOutcome? _selected;
  int _amount = 100;
  bool _choosingAmount = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final bet = widget.controller.market?.bet;
    if (bet?.isOpen == true) {
      _selected = bet!.outcome;
      _amount = bet.stake;
    } else {
      final unit = widget.controller.market!.stakeUnit;
      final initialUnits = math.max(1, 100 ~/ unit);
      _amount =
          math.min(widget.controller.spendingLimit ~/ unit, initialUnits) *
              unit;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final market = controller.market!;
          final selectedOption = market.options
              .where((option) => option.outcome == _selected)
              .firstOrNull;
          final total = selectedOption?.totalReturn(_amount);
          final optionDividerColor =
              Theme.of(context).brightness == Brightness.dark
                  ? AppPalette.lightGrey
                  : AppColors.of(context).divider;
          return Container(
            key: const ValueKey('match-betting-modal'),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .94,
            ),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(tr(context, 'Bets'),
                                style: Heading3.style)),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (_submitted) ...[
                      const Icon(Icons.check_circle_outline, size: 72),
                      const SizedBox(height: 16),
                      Text(tr(context, 'Bet Submitted!'),
                          style: Heading3.style),
                      const SizedBox(height: 12),
                      Text(
                        tr(context,
                            'Check back after the final whistle for the result.'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _BetButton(
                        text: tr(context, 'DONE'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ] else ...[
                      MatchStatsHeader(
                        homeTeam: widget.homeTeam,
                        awayTeam: widget.awayTeam,
                        options: market.options,
                        anchorTeamId: widget.anchorTeamId,
                      ),
                      const SizedBox(height: 20),
                      if (!_choosingAmount)
                        ...market.options.map(
                          (option) => Column(
                            children: [
                              Material(
                                type: MaterialType.transparency,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: SizedBox.square(
                                    dimension: 48,
                                    child: option.outcome == BetOutcome.draw
                                        ? _DrawTeamLogos(
                                            homeTeam: widget.homeTeam,
                                            awayTeam: widget.awayTeam,
                                          )
                                        : Center(
                                            child: _TeamLogo(
                                              team: option.outcome ==
                                                      BetOutcome.homeWin
                                                  ? widget.homeTeam
                                                  : widget.awayTeam,
                                            ),
                                          ),
                                  ),
                                  title: Text(
                                    _label(
                                      context,
                                      option.outcome,
                                      widget.homeTeam,
                                      widget.awayTeam,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${option.decimalOdds.toStringAsFixed(2)}×',
                                  ),
                                  trailing: Icon(
                                    _selected == option.outcome
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                  ),
                                  onTap: controller.saving
                                      ? null
                                      : () => setState(
                                            () => _selected = option.outcome,
                                          ),
                                ),
                              ),
                              Divider(
                                key: ValueKey(
                                  'match-betting-option-divider-'
                                  '${option.outcome.name}',
                                ),
                                color: optionDividerColor,
                              ),
                            ],
                          ),
                        ),
                      if (_choosingAmount) ...[
                        Text(
                          _label(context, _selected!, widget.homeTeam,
                              widget.awayTeam),
                          style: Heading5.style,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              key: const ValueKey('bet-decrease'),
                              onPressed: controller.saving ||
                                      _amount <= market.stakeUnit
                                  ? null
                                  : () => setState(
                                      () => _amount -= market.stakeUnit),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Flexible(
                              child: FittedBox(
                                child: Text(
                                    tr(context, '{points} pts',
                                        {'points': _amount}),
                                    style: Heading3.style),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('bet-increase'),
                              onPressed: controller.saving ||
                                      _amount + market.stakeUnit >
                                          controller.spendingLimit
                                  ? null
                                  : () => setState(
                                      () => _amount += market.stakeUnit),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        Text(tr(context, 'Available: {points} pts',
                            {'points': controller.spendingLimit})),
                        const SizedBox(height: 16),
                        if (total != null) ...[
                          Text(
                            tr(context, 'If correct: +{points} pts',
                                {'points': total - _amount}),
                            style: Heading5.style,
                          ),
                          Text(
                            tr(
                                context,
                                'Total return: {points} pts, including your stake.',
                                {'points': total}),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        TextButton(
                          onPressed: controller.saving
                              ? null
                              : () => setState(() => _choosingAmount = false),
                          child: Text(tr(context, 'CHANGE PICK')),
                        ),
                      ],
                      if (controller.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            tr(context, controller.error!),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (!controller.beforeKickoff)
                        Text(tr(context, 'Betting is closed for this match.')),
                      const SizedBox(height: 16),
                      _BetButton(
                        text: controller.saving
                            ? tr(context, 'SUBMITTING…')
                            : _choosingAmount
                                ? tr(context, 'CONFIRM BET')
                                : tr(context, 'CONTINUE'),
                        onPressed: _selected == null ||
                                !controller.canBet ||
                                _amount > controller.spendingLimit
                            ? null
                            : () async {
                                if (!_choosingAmount) {
                                  setState(() => _choosingAmount = true);
                                  return;
                                }
                                final saved = await controller.save(
                                  _selected!,
                                  _amount,
                                );
                                if (mounted && saved) {
                                  setState(() => _submitted = true);
                                }
                              },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class MatchStatsHeader extends StatelessWidget {
  const MatchStatsHeader({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    required this.options,
    this.anchorTeamId,
  });
  final Team homeTeam;
  final Team awayTeam;
  final List<BettingOption> options;
  final int? anchorTeamId;

  @override
  Widget build(BuildContext context) {
    final barColors = resolveBettingBarColors(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      background: _surface(context),
      anchorTeamId: anchorTeamId,
    );

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              key: const ValueKey('match-betting-home-team'),
              width: 40,
              child: _LabeledTeam(team: homeTeam),
            ),
            const Spacer(),
            Row(
              key: const ValueKey('match-betting-outcome-group'),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Column(
                    children: [
                      Container(
                        key: ValueKey('match-betting-odds-box-$index'),
                        width: 48,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${options[index].decimalOdds.toStringAsFixed(2)}×',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        ['W', 'D', 'L'][options[index].outcome.index],
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const Spacer(),
            SizedBox(
              key: const ValueKey('match-betting-away-team'),
              width: 40,
              child: _LabeledTeam(team: awayTeam),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (options.isNotEmpty)
          BettingProbabilityBar(
            values: options.map((option) => option.probability).toList(),
            colors: barColors,
          ),
        const SizedBox(height: 8),
        Row(
          children: BetOutcome.values
              .map(
                (outcome) => Expanded(
                  child: Text(
                    _label(context, outcome, homeTeam, awayTeam),
                    textAlign: TextAlign.center,
                    style: Body2.style,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class BettingParticipationCard extends StatelessWidget {
  const BettingParticipationCard({
    super.key,
    required this.controller,
    this.barColors,
  }) : assert(barColors == null || barColors.length == 3);

  final BettingController controller;
  final List<Color>? barColors;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final market = controller.market;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const ValueKey('match-h2h-bets-card'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.of(context).cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: appCardShadows(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1Touch', style: Body2_b.style),
                    const SizedBox(height: 12),
                    if (market?.available == true)
                      BettingProbabilityBar(
                        values: market!.options
                            .map((option) => option.probability)
                            .toList(),
                        colors: barColors,
                      )
                    else
                      Text(controller.loading
                          ? tr(context, 'Loading…')
                          : tr(context, 'Prediction unavailable.')),
                    const SizedBox(height: 20),
                    Text(tr(context, 'USER'), style: Body2_b.style),
                    const SizedBox(height: 12),
                    if (market?.userProbabilities != null)
                      BettingProbabilityBar(
                        values: market!.userProbabilities!,
                        colors: barColors,
                        selected:
                            ['open', 'won', 'lost'].contains(market.bet?.status)
                                ? market.bet?.outcome
                                : null,
                      )
                    else if (market != null)
                      Container(
                        key: const ValueKey('match-h2h-no-bets-bar'),
                        width: double.infinity,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppPalette.lightGrey,
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Text(
                          tr(context, 'No bets yet.'),
                          textAlign: TextAlign.center,
                          style: Heading5.style.copyWith(
                            color: AppPalette.white,
                            height: 1.10,
                          ),
                        ),
                      )
                    else
                      Text(
                        controller.loading
                            ? tr(context, 'Loading…')
                            : tr(context, 'Unable to load bets.'),
                      ),
                    if (market != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        tr(context, '{count} participants',
                            {'count': market.participantCount}),
                        style: Body2.style,
                      ),
                    ],
                    if (market?.bet?.isOpen == true &&
                        !controller.beforeKickoff)
                      TextButton(
                        onPressed: controller.loading ? null : controller.load,
                        child: Text(tr(context, 'REFRESH RESULT')),
                      ),
                    if (controller.error != null)
                      TextButton(
                        onPressed: controller.load,
                        child: Text(tr(context, 'RETRY')),
                      ),
                  ],
                ),
              ),
              if (market?.bet != null)
                _BetReceipt(
                  key: const ValueKey('match-h2h-bet-receipt'),
                  bet: market!.bet!,
                  label: [
                    'Home Win',
                    'Draw',
                    'Away Win'
                  ][market.bet!.outcome.index],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textAlign: TextAlign.left,
                  compact: true,
                ),
            ],
          );
        },
      );
}

class _BetReceipt extends StatelessWidget {
  const _BetReceipt({
    super.key,
    required this.bet,
    required this.label,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textAlign = TextAlign.center,
    this.compact = false,
  });

  final FixtureBet bet;
  final String label;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              _compactBetReceipt(context, bet),
              maxLines: 1,
              textAlign: TextAlign.left,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            '${tr(context, label)} · ${tr(context, '{points} pts', {
                  'points': bet.stake
                })}',
            textAlign: textAlign,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            bet.isOpen
                ? tr(
                    context,
                    'Return if correct: {points} pts (includes stake)',
                    {'points': bet.potentialReturn})
                : _settled(context, bet),
            textAlign: textAlign,
          ),
        ],
      ),
    );
  }
}

class BettingProbabilityBar extends StatelessWidget {
  const BettingProbabilityBar({
    super.key,
    required this.values,
    this.selected,
    this.colors,
  }) : assert(colors == null || colors.length == 3);

  final List<double> values;
  final BetOutcome? selected;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final segmentColors = colors ??
        const [
          Color(0xFFFF5757),
          Color(0xFFFFAAAA),
          AppPalette.lightGreyBox,
        ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 40,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalPadding = 8.0;
            final active = [
              for (var i = 0; i < 3; i++)
                if (values[i] > 0) i
            ];
            final labels = [
              for (var i = 0; i < 3; i++)
                '${(values[i] * 100).toStringAsFixed(1)}%'
            ];
            final minimums = <int, double>{};
            for (final index in active) {
              final painter = TextPainter(
                text: TextSpan(text: labels[index], style: Heading5.style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              minimums[index] = painter.width.ceilToDouble() +
                  horizontalPadding * 2 +
                  3 +
                  (selected?.index == index ? 14 : 0);
              painter.dispose();
            }
            final minimumWidth =
                minimums.values.fold<double>(0, (a, b) => a + b);
            final contentWidth = math.max(constraints.maxWidth, minimumWidth);
            final widths = <int, double>{};
            final flexible = active.toSet();
            var remainingWidth = contentWidth;
            var remainingWeight =
                active.fold<double>(0, (sum, i) => sum + values[i]);
            while (flexible.isNotEmpty) {
              final constrained = flexible.where((index) =>
                  remainingWidth * values[index] / remainingWeight <
                  minimums[index]!);
              if (constrained.isEmpty) break;
              for (final index in constrained.toList()) {
                widths[index] = minimums[index]!;
                remainingWidth -= widths[index]!;
                remainingWeight -= values[index];
                flexible.remove(index);
              }
            }
            for (final index in flexible) {
              widths[index] = remainingWidth * values[index] / remainingWeight;
            }
            final segments = Row(
              children: [
                for (final index in active)
                  SizedBox(
                    width: widths[index],
                    child: Container(
                      color: segmentColors[index],
                      padding: const EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      alignment: index == 0
                          ? Alignment.centerLeft
                          : index == 2
                              ? Alignment.centerRight
                              : Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (selected?.index == index && index == 2)
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: _foregroundFor(segmentColors[index]),
                            ),
                          Text(
                            labels[index],
                            maxLines: 1,
                            softWrap: false,
                            style: Heading5.style.copyWith(
                              color: _foregroundFor(segmentColors[index]),
                            ),
                          ),
                          if (selected?.index == index && index != 2)
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: _foregroundFor(segmentColors[index]),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
            if (minimumWidth <= constraints.maxWidth) return segments;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: contentWidth, child: segments),
            );
          },
        ),
      ),
    );
  }
}

Color _foregroundFor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : AppPalette.black;

class _BetButton extends StatelessWidget {
  const _BetButton({required this.text, required this.onPressed});
  final String text;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppPalette.white : AppPalette.black,
          foregroundColor: isDark ? AppPalette.black : AppPalette.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.team, this.size = 40});
  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = team.imagePath;
    return path == null || path.isEmpty
        ? teamLogoFallback(team.teamId, size: size)
        : Image.network(
            path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                teamLogoFallback(team.teamId, size: size),
          );
  }
}

class _DrawTeamLogos extends StatelessWidget {
  const _DrawTeamLogos({required this.homeTeam, required this.awayTeam});

  final Team homeTeam;
  final Team awayTeam;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: ClipPath(
              key: const ValueKey('match-betting-draw-home-clip'),
              clipper: const _DrawLogoHalfClipper(keepTopLeft: true),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox.square(
                  key: const ValueKey('match-betting-draw-home-logo'),
                  dimension: 36,
                  child: _TeamLogo(team: homeTeam, size: 36),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              key: const ValueKey('match-betting-draw-away-clip'),
              clipper: const _DrawLogoHalfClipper(keepTopLeft: false),
              child: Align(
                alignment: Alignment.bottomRight,
                child: SizedBox.square(
                  key: const ValueKey('match-betting-draw-away-logo'),
                  dimension: 36,
                  child: _TeamLogo(team: awayTeam, size: 36),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DrawLogoDividerPainter(
                  Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      );
}

class _DrawLogoHalfClipper extends CustomClipper<Path> {
  const _DrawLogoHalfClipper({required this.keepTopLeft});

  final bool keepTopLeft;

  @override
  Path getClip(Size size) => keepTopLeft
      ? (Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close())
      : (Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close());

  @override
  bool shouldReclip(_DrawLogoHalfClipper oldClipper) =>
      keepTopLeft != oldClipper.keepTopLeft;
}

class _DrawLogoDividerPainter extends CustomPainter {
  const _DrawLogoDividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DrawLogoDividerPainter oldDelegate) =>
      color != oldDelegate.color;
}

class _LabeledTeam extends StatelessWidget {
  const _LabeledTeam({required this.team});
  final Team team;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          _TeamLogo(team: team),
          const SizedBox(height: 6),
          Text(
            team.shortCode ?? teamNameLabel(context, team.teamId, team.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Body1_b.style,
          ),
        ],
      );
}

Color _surface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppPalette.darkGrey
        : AppPalette.white;
String _label(BuildContext context, BetOutcome outcome, Team home, Team away) =>
    switch (outcome) {
      BetOutcome.homeWin =>
        '${home.shortCode ?? teamNameLabel(context, home.teamId, home.name)} Win',
      BetOutcome.draw => 'Draw',
      BetOutcome.awayWin =>
        '${away.shortCode ?? teamNameLabel(context, away.teamId, away.name)} Win',
    };
String _unavailable(String? reason) => switch (reason) {
      'unsupported_competition' =>
        'Betting is available for supported league matches.',
      'kickoff_unconfirmed' => 'Betting opens when the kickoff is confirmed.',
      'prediction_unavailable' => 'Prediction unavailable for this match.',
      _ => 'Betting is closed for this match.',
    };
String _settled(BuildContext context, FixtureBet bet) => switch (bet.status) {
      'won' =>
        tr(context, 'Won · {points} pts returned', {'points': bet.payout}),
      'lost' => tr(context, 'Not correct · 0 pts returned'),
      'refunded' =>
        tr(context, 'Refunded · {points} pts returned', {'points': bet.payout}),
      'cancelled' =>
        tr(context, 'Refunded · {points} pts returned', {'points': bet.payout}),
      _ => tr(context, 'Waiting for the result'),
    };

TextSpan _compactBetReceipt(BuildContext context, FixtureBet bet) {
  if (bet.isOpen) {
    return TextSpan(
      text: tr(
        context,
        'You used {stake} pts · {return} pts if correct',
        {'stake': bet.stake, 'return': bet.potentialReturn},
      ),
      style: Body1.style,
    );
  }

  if (bet.status == 'won') {
    return _pointEmphasis(
      context,
      'You earned {points} from this bet! 🎉',
      bet.payout,
    );
  }

  if (bet.status == 'lost') {
    return TextSpan(
      text: tr(context, 'You earned no points from this bet.'),
      style: Body1.style,
    );
  }

  if (bet.status == 'refunded' || bet.status == 'cancelled') {
    return _pointEmphasis(
      context,
      '{points} were refunded from this bet.',
      bet.payout,
    );
  }

  return TextSpan(
    text: tr(context, 'Waiting for the result'),
    style: Body1.style,
  );
}

TextSpan _pointEmphasis(
  BuildContext context,
  String message,
  int points,
) {
  final pointText = tr(context, '{points} points', {'points': points});
  final sentence = tr(context, message, {'points': pointText});
  final pointStart = sentence.indexOf(pointText);
  if (pointStart < 0) return TextSpan(text: sentence, style: Body1.style);

  return TextSpan(
    style: Body1.style,
    children: [
      TextSpan(text: sentence.substring(0, pointStart)),
      TextSpan(text: pointText, style: Body1_b.style),
      TextSpan(text: sentence.substring(pointStart + pointText.length)),
    ],
  );
}
