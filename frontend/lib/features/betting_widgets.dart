import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/number_display.dart';
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
            width: double.infinity,
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
                if (market != null && bet == null) ...[
                  const SizedBox(height: 20),
                  Text(tr(context, "You’ve got {points} pts!", {
                    'points': NumberFormat.decimalPattern()
                        .format(market.wallet.balance),
                  })),
                ],
                if (bet?.isOpen == true) ...[
                  const SizedBox(height: 24),
                  Opacity(
                    opacity: .7,
                    child: Text(
                      tr(context, 'You’ve already placed a bet.'),
                      style: Body2.style,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(tr(context, controller.error!),
                      textAlign: TextAlign.center),
                  TextButton(
                    onPressed: controller.load,
                    child: Text(trUpper(context, 'Retry')),
                  ),
                ],
                if (controller.canBet) ...[
                  const SizedBox(height: 20),
                  _BetButton(
                    text: bet?.isOpen == true
                        ? tr(context, 'EDIT MY BET')
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

enum _BettingFlowStep { selection, amount, review, submitted }

class _BettingFlowModalState extends State<BettingFlowModal> {
  BetOutcome? _selected;
  int _amount = 100;
  _BettingFlowStep _step = _BettingFlowStep.selection;

  @override
  void initState() {
    super.initState();
    final bet = widget.controller.market?.bet;
    if (bet?.isOpen == true) {
      _selected = bet!.outcome;
      _amount = bet.stake;
    } else {
      final unit = widget.controller.market!.stakeUnit;
      // 기본 베팅액은 100을 기준으로 허용 단위 수를 정하고 지출 한도 내로 줄여요.
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
          final estimatedWin = total == null ? null : total - _amount;
          final optionDividerColor =
              Theme.of(context).brightness == Brightness.dark
                  ? AppPalette.lightGrey
                  : AppColors.of(context).divider;
          final closeButton = IconButton(
            key: const ValueKey('bet-flow-close'),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            icon: Icon(
              Icons.close,
              size: 24,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          );
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
                  24,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BetFlowHeader(
                      onBack: controller.saving ? null : _goBack,
                      closeButton: closeButton,
                      showBack: _step != _BettingFlowStep.submitted,
                    ),
                    if (_step == _BettingFlowStep.submitted) ...[
                      const SizedBox(height: 32),
                      const Icon(Icons.check_circle_outline, size: 56),
                      const SizedBox(height: 24),
                      Text(tr(context, 'Bet Submitted!'),
                          style: Heading3.style),
                      const SizedBox(height: 16),
                      Text(
                        tr(context, 'Check back after the final whistle…'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 48),
                      _BetButton(
                        text: trUpper(context, 'Done'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ] else ...[
                      if (_step != _BettingFlowStep.review) ...[
                        const SizedBox(height: 24),
                        MatchStatsHeader(
                          homeTeam: widget.homeTeam,
                          awayTeam: widget.awayTeam,
                          options: market.options,
                          anchorTeamId: widget.anchorTeamId,
                        ),
                      ],
                      if (_step == _BettingFlowStep.selection) ...[
                        const SizedBox(height: 32),
                        ...market.options.map(
                          (option) => Column(
                            children: [
                              Material(
                                type: MaterialType.transparency,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  titleAlignment: ListTileTitleAlignment.center,
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
                                    style: Heading5.style,
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
                      ],
                      if (_step == _BettingFlowStep.amount) ...[
                        const SizedBox(height: 32),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tr(context, 'You’re betting'),
                            style: Body2.style,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BetAmountInput(
                          amount: _amount,
                          onDecrease: controller.saving ||
                                  _amount <= market.stakeUnit
                              ? null
                              : () =>
                                  setState(() => _amount -= market.stakeUnit),
                          onIncrease: controller.saving ||
                                  _amount + market.stakeUnit >
                                      controller.spendingLimit
                              ? null
                              : () =>
                                  setState(() => _amount += market.stakeUnit),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Opacity(
                            opacity: .7,
                            child: Text(
                              tr(context, 'You can use up to {points} pts!', {
                                'points': NumberFormat.decimalPattern()
                                    .format(controller.spendingLimit),
                              }),
                              style: Body2.style,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (total != null && estimatedWin != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _BetValueBox(
                                  label: tr(context, 'Your estimated win'),
                                  value: estimatedWin,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _BetValueBox(
                                  label:
                                      tr(context, 'Total you’re getting back'),
                                  value: total,
                                ),
                              ),
                            ],
                          ),
                      ],
                      if (_step == _BettingFlowStep.review) ...[
                        const SizedBox(height: 32),
                        Text(
                          tr(context, 'You’re about to place a bet of'),
                          textAlign: TextAlign.center,
                          style: Body2.style,
                        ),
                        const SizedBox(height: 16),
                        _BetReviewAmount(amount: _amount),
                        const SizedBox(height: 16),
                        Text(
                          tr(context, 'Would you like to proceed?'),
                          textAlign: TextAlign.center,
                          style: Body2.style,
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
                      const SizedBox(height: 24),
                      _BetButton(
                        text: controller.saving
                            ? tr(context, 'SUBMITTING…')
                            : trUpper(context, 'Continue'),
                        onPressed: _selected == null ||
                                !controller.canBet ||
                                _amount > controller.spendingLimit
                            ? null
                            : () async {
                                if (_step == _BettingFlowStep.selection) {
                                  setState(
                                      () => _step = _BettingFlowStep.amount);
                                  return;
                                }
                                if (_step == _BettingFlowStep.amount) {
                                  setState(
                                      () => _step = _BettingFlowStep.review);
                                  return;
                                }
                                final saved = await controller.save(
                                  _selected!,
                                  _amount,
                                );
                                if (mounted && saved) {
                                  setState(
                                      () => _step = _BettingFlowStep.submitted);
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

  void _goBack() {
    switch (_step) {
      case _BettingFlowStep.selection:
        Navigator.pop(context);
        return;
      case _BettingFlowStep.amount:
        setState(() => _step = _BettingFlowStep.selection);
        return;
      case _BettingFlowStep.review:
        setState(() => _step = _BettingFlowStep.amount);
        return;
      case _BettingFlowStep.submitted:
        return;
    }
  }
}

class _BetFlowHeader extends StatelessWidget {
  const _BetFlowHeader({
    required this.onBack,
    required this.closeButton,
    required this.showBack,
  });

  final VoidCallback? onBack;
  final Widget closeButton;
  final bool showBack;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const ValueKey('bet-flow-header'),
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(child: Text(tr(context, 'Bets'), style: Heading5.style)),
            if (showBack)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const ValueKey('bet-flow-back'),
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
            Align(alignment: Alignment.centerRight, child: closeButton),
          ],
        ),
      );
}

class _BetValueBox extends StatelessWidget {
  const _BetValueBox({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Body2.style),
          const SizedBox(height: 12),
          Container(
            key: ValueKey('bet-value-$label'),
            width: double.infinity,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppPalette.lightGrey
                  : AppPalette.lightGreyBox,
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$value', style: Heading5.style),
                    TextSpan(
                      text: ' ${_pointsUnit(context)}',
                      style: Heading5.style.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

class _BetReviewAmount extends StatelessWidget {
  const _BetReviewAmount({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('bet-review-amount'),
        width: double.infinity,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppPalette.lightGrey
              : AppPalette.lightGreyBox,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$amount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' ${_pointsUnit(context)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ).copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .5),
                ),
              ),
            ],
          ),
        ),
      );
}

class _BetAmountInput extends StatelessWidget {
  const _BetAmountInput({
    required this.amount,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int amount;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    // 서버의 금액 규칙은 유지하고, 기존 금액 박스와 오른쪽 버튼 배치를 복원해요.
    return Container(
      key: const ValueKey('match-betting-amount-input'),
      padding: const EdgeInsets.only(top: 12, left: 16, right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppPalette.lightGrey
            : AppPalette.lightGreyBox,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$amount',
                      style: TextStyle(
                          color: foreground,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _pointsUnit(context),
                      style: TextStyle(
                          color: foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _BetAmountButton(
                buttonKey: const ValueKey('bet-decrease'),
                action: _BetAmountAction.decrease,
                onPressed: onDecrease,
              ),
              const SizedBox(width: 12),
              _BetAmountButton(
                buttonKey: const ValueKey('bet-increase'),
                action: _BetAmountAction.increase,
                onPressed: onIncrease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BetAmountAction { decrease, increase }

class _BetAmountButton extends StatelessWidget {
  const _BetAmountButton({
    required this.buttonKey,
    required this.action,
    required this.onPressed,
  });

  final Key buttonKey;
  final _BetAmountAction action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        onPressed == null ? theme.disabledColor : theme.colorScheme.onSurface;
    return SizedBox.square(
      dimension: 32,
      child: IconButton(
        key: buttonKey,
        onPressed: onPressed,
        icon: CustomPaint(
          size: const Size.square(20),
          painter: _BetAmountGlyphPainter(
            color: foreground,
            showVerticalLine: action == _BetAmountAction.increase,
          ),
        ),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: foreground,
          shape: const CircleBorder(),
          side: BorderSide(color: foreground, width: 2),
        ),
      ),
    );
  }
}

class _BetAmountGlyphPainter extends CustomPainter {
  const _BetAmountGlyphPainter({
    required this.color,
    required this.showVerticalLine,
  });

  final Color color;
  final bool showVerticalLine;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    final center = size.center(Offset.zero);
    canvas.drawLine(
      Offset(4, center.dy),
      Offset(size.width - 4, center.dy),
      paint,
    );
    if (showVerticalLine) {
      canvas.drawLine(
        Offset(center.dx, 4),
        Offset(center.dx, size.height - 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BetAmountGlyphPainter oldDelegate) =>
      color != oldDelegate.color ||
      showVerticalLine != oldDelegate.showVerticalLine;
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
    final oddsLabels = [
      for (final option in options)
        '${formatDisplayNumber(option.decimalOdds)}×',
    ];
    final oddsTextStyle = Heading4.style.copyWith(color: AppPalette.white);

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              key: const ValueKey('match-betting-home-team'),
              width: 40,
              child: _LabeledTeam(team: homeTeam),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (options.isEmpty) return const SizedBox.shrink();
                  const gap = 8.0;
                  const horizontalPadding = 8.0;
                  const textSafetyInset = 2.0;
                  final boxWidth =
                      (constraints.maxWidth - gap * (options.length - 1)) /
                          options.length;
                  final textWidths = oddsLabels.map((label) {
                    final painter = TextPainter(
                      text: TextSpan(text: label, style: oddsTextStyle),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    )..layout();
                    final width = painter.width;
                    painter.dispose();
                    return width;
                  });
                  final longestTextWidth = textWidths.fold<double>(0, math.max);
                  final availableTextWidth = math.max(
                    0,
                    boxWidth - horizontalPadding * 2 - textSafetyInset * 2,
                  );
                  // 가장 긴 배당을 기준으로 모든 숫자를 같은 비율로 줄여요.
                  final commonScale = longestTextWidth <= availableTextWidth
                      ? 1.0
                      : availableTextWidth / longestTextWidth;
                  final responsiveOddsStyle = oddsTextStyle.copyWith(
                    fontSize: oddsTextStyle.fontSize! * commonScale,
                  );

                  return Row(
                    key: const ValueKey('match-betting-outcome-group'),
                    children: [
                      for (var index = 0; index < options.length; index++) ...[
                        if (index > 0) const SizedBox(width: gap),
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                key: ValueKey('match-betting-odds-box-$index'),
                                height: 32,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                  vertical: 4,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppPalette.black,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  oddsLabels[index],
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.center,
                                  style: responsiveOddsStyle,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tr(
                                    context,
                                    [
                                      'W',
                                      'D',
                                      'L'
                                    ][options[index].outcome.index]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
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
            values: bettingProbabilitiesByOutcome(options),
            colors: barColors,
            outcomeLabels: [
              for (final outcome in BetOutcome.values)
                _label(context, outcome, homeTeam, awayTeam),
            ],
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
                    Text('1TOUCH', style: Body2_b.style),
                    const SizedBox(height: 12),
                    if (market?.available == true)
                      BettingProbabilityBar(
                        values: bettingProbabilitiesByOutcome(market!.options),
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
                        child: Text(trUpper(context, 'Retry')),
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
    this.outcomeLabels,
  })  : assert(colors == null || colors.length == 3),
        assert(outcomeLabels == null || outcomeLabels.length == 3);

  final List<double> values;
  final BetOutcome? selected;
  final List<Color>? colors;
  final List<String>? outcomeLabels;

  @override
  Widget build(BuildContext context) {
    final segmentColors = colors ??
        const [
          Color(0xFFFF5757),
          Color(0xFFFFAAAA),
          AppPalette.lightGreyBox,
        ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 8.0;
        final active = [
          for (var i = 0; i < 3; i++)
            if (values[i] > 0) i
        ];
        final labels = [
          for (var i = 0; i < 3; i++) '${(values[i] * 100).toStringAsFixed(1)}%'
        ];
        final minimums = <int, double>{};
        for (final index in active) {
          final percentagePainter = TextPainter(
            text: TextSpan(text: labels[index], style: Heading5.style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final percentageMinimum = percentagePainter.width.ceilToDouble() +
              horizontalPadding * 2 +
              (selected?.index == index ? 14 : 0);
          percentagePainter.dispose();

          minimums[index] = percentageMinimum;
        }
        final minimumWidth = minimums.values.fold<double>(0, (a, b) => a + b);
        // 확률 비율로 너비를 나누기 전에 각 라벨의 최소 폭을 확보해요.
        // 최소 폭에 걸린 칸을 고정한 뒤 남은 폭만 나머지 확률대로 다시 나눠요.
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
                key: ValueKey('betting-probability-segment-$index'),
                width: widths[index],
                child: Container(
                  color: segmentColors[index],
                  padding: const EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  alignment:
                      index == 0 ? Alignment.centerLeft : Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
              ),
          ],
        );
        final content = Column(
          children: [
            ClipRRect(
              key: const ValueKey('betting-probability-bar-surface'),
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(height: 40, child: segments),
            ),
            if (outcomeLabels != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final index in active)
                    SizedBox(
                      width: widths[index],
                      child: Text(
                        key: ValueKey('betting-outcome-label-$index'),
                        outcomeLabels![index],
                        maxLines: 1,
                        softWrap: false,
                        textAlign: switch (index) {
                          0 => TextAlign.left,
                          2 => TextAlign.right,
                          _ => TextAlign.center,
                        },
                        style: Body2.style,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
        if (minimumWidth <= constraints.maxWidth) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: contentWidth, child: content),
        );
      },
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
  Widget build(BuildContext context) {
    final label = _teamBettingLabel(team);
    return Column(
      children: [
        _TeamLogo(team: team),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Body1_b.style,
          ),
        ],
      ],
    );
  }
}

Color _surface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? AppPalette.darkGrey
        : AppPalette.white;
String _pointsUnit(BuildContext context) =>
    tr(context, '{points} pts', {'points': ''}).trim();
// 베팅 화면에서는 팀 코드나 짧은 이름만 표시해요.
String _teamBettingLabel(Team team) {
  final shortCode = team.shortCode?.trim();
  if (shortCode != null && shortCode.isNotEmpty) return shortCode;
  final shortName = team.shortName?.trim();
  if (shortName != null && shortName.isNotEmpty) return shortName;
  return '';
}

String _label(BuildContext context, BetOutcome outcome, Team home, Team away) =>
    switch (outcome) {
      BetOutcome.homeWin =>
        tr(context, '{team} Win', {'team': _teamBettingLabel(home)}).trim(),
      BetOutcome.draw => tr(context, 'Draw'),
      BetOutcome.awayWin =>
        tr(context, '{team} Win', {'team': _teamBettingLabel(away)}).trim(),
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
