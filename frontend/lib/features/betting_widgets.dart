import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/betting.dart';
import 'package:onetouch/models/team.dart';

class MatchBettingSection extends StatelessWidget {
  const MatchBettingSection({
    super.key,
    required this.controller,
    required this.homeTeam,
    required this.awayTeam,
  });
  final BettingController controller;
  final Team homeTeam;
  final Team awayTeam;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final market = controller.market;
          final bet = market?.bet;
          return Container(
            key: const ValueKey('match-betting-card'),
            padding: const EdgeInsets.all(16),
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
                  ),
                if (market == null && controller.loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                if (market != null &&
                    (!market.canBet || !controller.beforeKickoff))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(_unavailable(market.unavailableReason)),
                  ),
                if (market != null) ...[
                  const SizedBox(height: 20),
                  Text("You’ve got ${market.wallet.balance} pts!"),
                ],
                if (bet != null)
                  _BetReceipt(
                    bet: bet,
                    label: _label(bet.outcome, homeTeam, awayTeam),
                  ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(controller.error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: controller.load,
                    child: const Text('RETRY'),
                  ),
                ],
                if (controller.canBet) ...[
                  const SizedBox(height: 20),
                  _BetButton(
                    text: bet?.isOpen == true ? 'EDIT BET' : 'PLACE A BET',
                    onPressed: controller.spendingLimit < 10
                        ? null
                        : () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => BettingFlowModal(
                                controller: controller,
                                homeTeam: homeTeam,
                                awayTeam: awayTeam,
                              ),
                            ),
                  ),
                  if (controller.spendingLimit < 10)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('You need at least 10 pts to place a bet.'),
                    ),
                ],
                if (controller.canCancel)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel your bet?'),
                          content: Text('${bet!.stake} pts will be returned.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('KEEP BET'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('CANCEL BET'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await controller.cancel();
                    },
                    child: const Text('CANCEL BET'),
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
  });
  final BettingController controller;
  final Team homeTeam;
  final Team awayTeam;
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
      _amount = (widget.controller.spendingLimit ~/ 10 * 10).clamp(10, 100);
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
                        const Expanded(
                            child: Text('Bets', style: Heading3.style)),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (_submitted) ...[
                      const Icon(Icons.check_circle_outline, size: 72),
                      const SizedBox(height: 16),
                      const Text('Bet Submitted!', style: Heading3.style),
                      const SizedBox(height: 12),
                      const Text(
                        'Check back after the final whistle for the result.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _BetButton(
                        text: 'DONE',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ] else ...[
                      MatchStatsHeader(
                        homeTeam: widget.homeTeam,
                        awayTeam: widget.awayTeam,
                        options: market.options,
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
                                  leading: option.outcome == BetOutcome.draw
                                      ? const Icon(Icons.handshake_outlined,
                                          size: 36)
                                      : _TeamLogo(
                                          team: option.outcome ==
                                                  BetOutcome.homeWin
                                              ? widget.homeTeam
                                              : widget.awayTeam,
                                        ),
                                  title: Text(
                                    _label(
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
                              const Divider(),
                            ],
                          ),
                        ),
                      if (_choosingAmount) ...[
                        Text(
                          _label(_selected!, widget.homeTeam, widget.awayTeam),
                          style: Heading5.style,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              key: const ValueKey('bet-decrease'),
                              onPressed: controller.saving || _amount <= 10
                                  ? null
                                  : () => setState(() => _amount -= 10),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Flexible(
                              child: FittedBox(
                                child:
                                    Text('$_amount pts', style: Heading3.style),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('bet-increase'),
                              onPressed: controller.saving ||
                                      _amount + 10 > controller.spendingLimit
                                  ? null
                                  : () => setState(() => _amount += 10),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        Text('Available: ${controller.spendingLimit} pts'),
                        const SizedBox(height: 16),
                        if (total != null) ...[
                          Text(
                            'If correct: +${total - _amount} pts',
                            style: Heading5.style,
                          ),
                          Text(
                            'Total return: $total pts, including your stake.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        TextButton(
                          onPressed: controller.saving
                              ? null
                              : () => setState(() => _choosingAmount = false),
                          child: const Text('CHANGE PICK'),
                        ),
                      ],
                      if (controller.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            controller.error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (!controller.beforeKickoff)
                        const Text('Betting is closed for this match.'),
                      const SizedBox(height: 16),
                      _BetButton(
                        text: controller.saving
                            ? 'SUBMITTING…'
                            : _choosingAmount
                                ? 'CONFIRM BET'
                                : 'CONTINUE',
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
  });
  final Team homeTeam;
  final Team awayTeam;
  final List<BettingOption> options;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(child: _LabeledTeam(team: homeTeam)),
              Expanded(
                flex: 3,
                child: Row(
                  children: options
                      .map(
                        (option) => Expanded(
                          child: Column(
                            children: [
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppPalette.black,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FittedBox(
                                  child: Text(
                                    '${option.decimalOdds.toStringAsFixed(2)}×',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(['W', 'D', 'L'][option.outcome.index]),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(child: _LabeledTeam(team: awayTeam)),
            ],
          ),
          const SizedBox(height: 20),
          if (options.isNotEmpty)
            BettingProbabilityBar(
              values: options.map((option) => option.probability).toList(),
            ),
          const SizedBox(height: 8),
          Row(
            children: BetOutcome.values
                .map(
                  (outcome) => Expanded(
                    child: Text(
                      _label(outcome, homeTeam, awayTeam),
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            key: const ValueKey('match-h2h-bets-card'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.lightGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: appCardShadows(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1Touch', style: Body2_b.style),
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
                      ? 'Loading…'
                      : 'Prediction unavailable.'),
                const SizedBox(height: 20),
                const Text('USER', style: Body2_b.style),
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
                else
                  Text(
                    controller.loading
                        ? 'Loading…'
                        : market == null
                            ? 'Unable to load bets.'
                            : 'No bets yet.',
                  ),
                if (market != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${market.participantCount} participants · Home / Draw / Away',
                    style: Body2.style,
                  ),
                ],
                if (market?.bet != null)
                  _BetReceipt(
                    bet: market!.bet!,
                    label: [
                      'Home Win',
                      'Draw',
                      'Away Win'
                    ][market.bet!.outcome.index],
                  ),
                if (market?.bet?.isOpen == true && !controller.beforeKickoff)
                  TextButton(
                    onPressed: controller.loading ? null : controller.load,
                    child: const Text('REFRESH RESULT'),
                  ),
                if (controller.error != null)
                  TextButton(
                    onPressed: controller.load,
                    child: const Text('RETRY'),
                  ),
              ],
            ),
          );
        },
      );
}

class _BetReceipt extends StatelessWidget {
  const _BetReceipt({required this.bet, required this.label});
  final FixtureBet bet;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Text(
              '$label · ${bet.stake} pts',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              bet.isOpen
                  ? 'Return if correct: ${bet.potentialReturn} pts (includes stake)'
                  : _settled(bet),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
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
        child: Row(
          children: List.generate(3, (index) {
            if (values[index] <= 0) return const SizedBox.shrink();
            return Expanded(
              flex: (values[index] * 1000000).round().clamp(1, 1000000),
              child: Container(
                color: segmentColors[index],
                padding: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                child: FittedBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(values[index] * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _foregroundFor(segmentColors[index]),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (selected?.index == index)
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: _foregroundFor(segmentColors[index]),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
  const _TeamLogo({required this.team});
  final Team team;
  @override
  Widget build(BuildContext context) {
    final path = team.imagePath;
    return path == null || path.isEmpty
        ? teamLogoFallback(team.teamId, size: 40)
        : Image.network(
            path,
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                teamLogoFallback(team.teamId, size: 40),
          );
  }
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
            team.shortCode ?? team.name,
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
String _label(BetOutcome outcome, Team home, Team away) => switch (outcome) {
      BetOutcome.homeWin => '${home.shortCode ?? home.name} Win',
      BetOutcome.draw => 'Draw',
      BetOutcome.awayWin => '${away.shortCode ?? away.name} Win',
    };
String _unavailable(String? reason) => switch (reason) {
      'unsupported_competition' =>
        'Betting is available for supported league matches.',
      'kickoff_unconfirmed' => 'Betting opens when the kickoff is confirmed.',
      'prediction_unavailable' => 'Prediction unavailable for this match.',
      _ => 'Betting is closed for this match.',
    };
String _settled(FixtureBet bet) => switch (bet.status) {
      'won' => 'Won · ${bet.payout} pts returned',
      'lost' => 'Not correct · 0 pts returned',
      'refunded' => 'Match refunded · ${bet.payout} pts returned',
      'cancelled' => 'Cancelled · ${bet.payout} pts returned',
      _ => 'Waiting for the result',
    };
