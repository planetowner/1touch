import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/team_probability.dart';

class TeamProbabilityWhatIfScreen extends StatefulWidget {
  const TeamProbabilityWhatIfScreen({
    super.key,
    required this.snapshot,
    required this.event,
    required this.teamPrimaryColor,
    this.homeTeam,
    this.awayTeam,
  });

  final TeamProbabilitySnapshot snapshot;
  final String event;
  final Color teamPrimaryColor;
  final Team? homeTeam;
  final Team? awayTeam;

  @override
  State<TeamProbabilityWhatIfScreen> createState() =>
      _TeamProbabilityWhatIfScreenState();
}

class _TeamProbabilityWhatIfScreenState
    extends State<TeamProbabilityWhatIfScreen> {
  String? _selectedOutcome;

  @override
  Widget build(BuildContext context) {
    final whatIf = widget.snapshot.whatIf;
    final colors = AppColors.of(context);
    final contentTop = appBarContentTop(context);
    if (whatIf == null) {
      return Scaffold(
        backgroundColor: mainPageBackground(context),
        body: SafeArea(
          child: Center(
            child: Text(tr(context, 'What-if data is unavailable.')),
          ),
        ),
      );
    }

    final currentEvent = _findEvent(widget.snapshot.cards, widget.event);
    final focusTeam = whatIf.fixture.homeTeamId == widget.snapshot.teamId
        ? widget.homeTeam
        : widget.awayTeam;
    final focusTeamName = focusTeam?.displayName ?? widget.snapshot.teamName;
    final scenarios = <_ScenarioViewData>[
      for (final outcome in const ['win', 'draw', 'loss'])
        if (_findScenario(whatIf.scenarios, outcome) case final scenario?)
          if (_findEvent(scenario.events, widget.event) case final event?)
            _ScenarioViewData(
              outcome: outcome,
              probability: event.probability,
              delta: event.probability - (currentEvent?.probability ?? 0),
            ),
    ];

    return Scaffold(
      key: const ValueKey('team-probability-what-if-screen'),
      backgroundColor: mainPageBackground(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, contentTop, 24, 48),
        children: [
          _WhatIfAppBar(onBack: () => Navigator.of(context).pop()),
          const SizedBox(height: 24),
          Text(
            tr(
              context,
              "IF {team}'S NEXT MATCH ENDS WITH",
              {'team': focusTeamName.toUpperCase()},
            ),
            style: Body2_b.style,
          ),
          const SizedBox(height: 24),
          _OutcomeCard(
            whatIf: whatIf,
            teamId: widget.snapshot.teamId,
            homeTeam: widget.homeTeam,
            awayTeam: widget.awayTeam,
            selectedOutcome: _selectedOutcome,
            onSelected: (outcome) => setState(() => _selectedOutcome = outcome),
          ),
          const SizedBox(height: 48),
          Text(_eventSectionTitle(context, widget.event), style: Body2_b.style),
          const SizedBox(height: 24),
          if (scenarios.length == 3) ...[
            _ScenarioChart(
              scenarios: scenarios,
              color: widget.teamPrimaryColor,
              selectedOutcome: _selectedOutcome,
            ),
            const SizedBox(height: 16),
            _ScenarioExplanation(
              teamName: focusTeamName,
              scenarios: scenarios,
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: appCardShadows(context),
              ),
              child: Text(
                tr(context, 'What-if data is unavailable for this outcome.'),
                style: Body1.style,
              ),
            ),
        ],
      ),
    );
  }
}

class _WhatIfAppBar extends StatelessWidget {
  const _WhatIfAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('what-if-back-button'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 24),
            ),
          ),
          Text(tr(context, 'What if?'), style: Body1.style),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('what-if-search-button'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.search, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.whatIf,
    required this.teamId,
    required this.homeTeam,
    required this.awayTeam,
    required this.selectedOutcome,
    required this.onSelected,
  });

  final TeamProbabilityWhatIf whatIf;
  final int teamId;
  final Team? homeTeam;
  final Team? awayTeam;
  final String? selectedOutcome;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final fixture = whatIf.fixture;
    final colors = AppColors.of(context);
    return Container(
      key: const ValueKey('what-if-outcome-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.subtleBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: appCardShadows(context),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _TeamIdentity(team: homeTeam, id: fixture.homeTeamId)),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                child: _FixtureTime(
                  roundName: fixture.roundName,
                  startingAt: fixture.startingAt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: _TeamIdentity(team: awayTeam, id: fixture.awayTeamId)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            child: RadioGroup<String>(
              groupValue: selectedOutcome,
              onChanged: (value) {
                if (value != null) onSelected(value);
              },
              child: Column(
                children: [
                  for (var index = 0; index < 3; index++) ...[
                    _OutcomeOption(
                      outcome: const ['win', 'draw', 'loss'][index],
                      teamId: teamId,
                      fixture: fixture,
                      homeTeam: homeTeam,
                      awayTeam: awayTeam,
                      onTap: onSelected,
                    ),
                    if (index < 2) Divider(height: 1, color: colors.divider),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamIdentity extends StatelessWidget {
  const _TeamIdentity({required this.team, required this.id});

  final Team? team;
  final int id;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TeamLogo(url: team?.imagePath, size: 72),
        const SizedBox(height: 8),
        Text(
          team?.displayName ?? 'Team $id',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Body1.style,
        ),
      ],
    );
  }
}

class _FixtureTime extends StatelessWidget {
  const _FixtureTime({required this.roundName, required this.startingAt});

  final String? roundName;
  final DateTime startingAt;

  @override
  Widget build(BuildContext context) {
    final local = startingAt.toLocal();
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      children: [
        Text(
          _roundLabel(context, roundName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Body1.style,
        ),
        const SizedBox(height: 8),
        SizedBox(
            width: 48, child: Divider(color: AppColors.of(context).divider)),
        const SizedBox(height: 8),
        Text(
          '${DateFormat('EEE, MMM d', locale).format(local)}\n${DateFormat('h:mm a', locale).format(local)}',
          textAlign: TextAlign.center,
          style: Body1.style,
        ),
      ],
    );
  }
}

class _OutcomeOption extends StatelessWidget {
  const _OutcomeOption({
    required this.outcome,
    required this.teamId,
    required this.fixture,
    required this.homeTeam,
    required this.awayTeam,
    required this.onTap,
  });

  final String outcome;
  final int teamId;
  final TeamProbabilityWhatIfFixture fixture;
  final Team? homeTeam;
  final Team? awayTeam;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isHomeTeam = fixture.homeTeamId == teamId;
    final selectedTeam = outcome == 'win'
        ? (isHomeTeam ? homeTeam : awayTeam)
        : outcome == 'loss'
            ? (isHomeTeam ? awayTeam : homeTeam)
            : null;
    final label = outcome == 'draw'
        ? tr(context, 'Draw')
        : '${selectedTeam?.shortCode ?? selectedTeam?.shortName ?? selectedTeam?.name ?? tr(context, 'Team')} ${tr(context, 'Win')}';
    return InkWell(
      key: ValueKey('what-if-outcome-$outcome'),
      onTap: () => onTap(outcome),
      child: SizedBox(
        height: 96,
        child: Row(
          children: [
            _OutcomeLogo(
              outcome: outcome,
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              selectedTeam: selectedTeam,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Heading5.style,
              ),
            ),
            Radio<String>(value: outcome),
          ],
        ),
      ),
    );
  }
}

class _OutcomeLogo extends StatelessWidget {
  const _OutcomeLogo({
    required this.outcome,
    required this.homeTeam,
    required this.awayTeam,
    required this.selectedTeam,
  });

  final String outcome;
  final Team? homeTeam;
  final Team? awayTeam;
  final Team? selectedTeam;

  @override
  Widget build(BuildContext context) {
    if (outcome != 'draw') {
      return _TeamLogo(url: selectedTeam?.imagePath, size: 48);
    }
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Align(
              alignment: Alignment.topLeft,
              child: _TeamLogo(url: homeTeam?.imagePath, size: 32)),
          Align(
              alignment: Alignment.bottomRight,
              child: _TeamLogo(url: awayTeam?.imagePath, size: 32)),
        ],
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return SizedBox(
          width: size, height: size, child: const Icon(Icons.shield_outlined));
    }
    return Image.network(
      url!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.shield_outlined),
      ),
    );
  }
}

class _ScenarioViewData {
  const _ScenarioViewData({
    required this.outcome,
    required this.probability,
    required this.delta,
  });

  final String outcome;
  final double probability;
  final double delta;
}

class _ScenarioChart extends StatelessWidget {
  const _ScenarioChart({
    required this.scenarios,
    required this.color,
    required this.selectedOutcome,
  });

  final List<_ScenarioViewData> scenarios;
  final Color color;
  final String? selectedOutcome;

  @override
  Widget build(BuildContext context) {
    final maxProbability = scenarios
        .map((item) => item.probability)
        .fold<double>(
            0, (previous, value) => value > previous ? value : previous);
    final colors = AppColors.of(context);
    return Container(
      key: const ValueKey('what-if-scenario-chart'),
      height: 260,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: appCardShadows(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < scenarios.length; index++) ...[
            if (index > 0) const SizedBox(width: 16),
            Expanded(
              child: _ScenarioBar(
                data: scenarios[index],
                heightFactor: maxProbability == 0
                    ? 0
                    : scenarios[index].probability / maxProbability,
                color: color.withValues(
                  alpha: selectedOutcome == null ||
                          selectedOutcome == scenarios[index].outcome
                      ? (1 - index * .25)
                      : .18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScenarioBar extends StatelessWidget {
  const _ScenarioBar({
    required this.data,
    required this.heightFactor,
    required this.color,
  });

  final _ScenarioViewData data;
  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final positive = data.delta >= 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('${(data.probability * 100).round()}%', style: Body1.style),
        const SizedBox(height: 8),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor.clamp(.04, 1),
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(tr(context, _outcomeLabelKey(data.outcome)),
            textAlign: TextAlign.center, style: Body2_b.style),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              positive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              size: 24,
              color:
                  positive ? const Color(0xFF3DDC97) : const Color(0xFFFF5964),
            ),
            Text('${(data.delta.abs() * 100).round()}%', style: Body2.style),
          ],
        ),
      ],
    );
  }
}

class _ScenarioExplanation extends StatelessWidget {
  const _ScenarioExplanation({required this.teamName, required this.scenarios});

  final String teamName;
  final List<_ScenarioViewData> scenarios;

  @override
  Widget build(BuildContext context) {
    final win = scenarios.firstWhere((item) => item.outcome == 'win');
    final loss = scenarios.firstWhere((item) => item.outcome == 'loss');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline,
            size: 24, color: AppColors.of(context).mutedForeground),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            tr(
              context,
              "A win could change {team}'s probability by {win} percentage points, while a loss could change it by {loss} points.",
              {
                'team': teamName,
                'win': (win.delta * 100).toStringAsFixed(1),
                'loss': (loss.delta * 100).toStringAsFixed(1),
              },
            ),
            style: Body1.style
                .copyWith(color: AppColors.of(context).mutedForeground),
          ),
        ),
      ],
    );
  }
}

TeamProbabilityWhatIfScenario? _findScenario(
  List<TeamProbabilityWhatIfScenario> scenarios,
  String outcome,
) {
  for (final scenario in scenarios) {
    if (scenario.outcome == outcome) return scenario;
  }
  return null;
}

TeamProbabilityCard? _findEvent(
  List<TeamProbabilityCard> events,
  String event,
) {
  for (final item in events) {
    if (item.event == event) return item;
  }
  return null;
}

String _roundLabel(BuildContext context, String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return tr(context, 'Next match');
  final number = int.tryParse(value);
  return number == null ? value : '${tr(context, 'Round')} $number';
}

String _outcomeLabelKey(String outcome) => switch (outcome) {
      'win' => 'If win',
      'draw' => 'If draw',
      _ => 'If loss',
    };

String _eventSectionTitle(BuildContext context, String event) =>
    switch (event) {
      'league_winner' => tr(context, 'LEAGUE WINNER PROBABILITY'),
      'top_four' || 'top_4' => tr(context, 'TOP 4 PROBABILITY'),
      'direct_relegation' ||
      'relegation_playoff' =>
        tr(context, 'RELEGATION PROBABILITY'),
      _ => trUpper(context, 'Probability'),
    };
