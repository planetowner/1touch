import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
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
    final focusTeamName = teamNameLabel(context, widget.snapshot.teamId,
        focusTeam?.displayName ?? widget.snapshot.teamName,
        short: true);
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
        padding: EdgeInsets.fromLTRB(24, contentTop, 24, 24),
        children: [
          _WhatIfAppBar(onBack: () => Navigator.of(context).pop()),
          const SizedBox(height: 24),
          Text(
            tr(
              context,
              "IF {team}'S NEXT MATCH ENDS WITH",
              {
                'team': Localizations.localeOf(context).languageCode == 'en'
                    ? focusTeamName.toUpperCase()
                    : focusTeamName
              },
            ),
            style: Body2_b.style,
          ),
          const SizedBox(height: 24),
          _OutcomeCard(
            whatIf: whatIf,
            teamId: widget.snapshot.teamId,
            competitionId: widget.snapshot.competitionId,
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
              event: widget.event,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(tr(context, 'What if?'),
                textAlign: TextAlign.center, style: Body1.style),
          ),
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
    required this.competitionId,
    required this.homeTeam,
    required this.awayTeam,
    required this.selectedOutcome,
    required this.onSelected,
  });

  final TeamProbabilityWhatIf whatIf;
  final int teamId;
  final int competitionId;
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
                  competitionId: competitionId,
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
          teamNameLabel(context, id, team?.displayName ?? 'Team $id',
              short: true),
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
  const _FixtureTime(
      {required this.competitionId,
      required this.roundName,
      required this.startingAt});

  final int competitionId;
  final String? roundName;
  final DateTime startingAt;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Column(
      children: [
        Text(
          competitionRoundLabel(context,
              competitionId: competitionId, roundName: roundName),
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
          fixtureDateLabel(startingAt, locale: locale),
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
    final selectedTeamId = (outcome == 'win') == isHomeTeam
        ? fixture.homeTeamId
        : fixture.awayTeamId;
    final label = outcome == 'draw'
        ? teamScreenLabel(context, 'Draw')
        : tr(context, '{team} Win', {
            'team': selectedTeam?.shortCode ??
                teamNameLabel(context, selectedTeamId,
                    selectedTeam?.displayName ?? tr(context, 'Team'),
                    short: true),
          });
    return InkWell(
      key: ValueKey('what-if-outcome-$outcome'),
      onTap: () => onTap(outcome),
      child: SizedBox(
        height: 96,
        child: Row(
          children: [
            _OutcomeLogo(
              key: ValueKey('what-if-outcome-logo-$outcome'),
              outcome: outcome,
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              selectedTeam: selectedTeam,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Heading5.style),
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
    super.key,
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
    // 세 시나리오 중 가장 높은 확률을 막대 높이 100%로 삼아 상대 높이를 비교해요.
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
                  alpha: selectedOutcome == null
                      ? 1 - index * .25
                      : selectedOutcome == scenarios[index].outcome
                          ? 1
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
              // 0%도 막대 위치가 보이도록 최소 높이를 4%로 둬요.
              heightFactor: heightFactor.clamp(.04, 1),
              widthFactor: 1,
              child: DecoratedBox(
                key: ValueKey('what-if-scenario-bar-${data.outcome}'),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                positive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 24,
                color: positive
                    ? const Color(0xFF3DDC97)
                    : const Color(0xFFFF5964),
              ),
              Text('${(data.delta.abs() * 100).round()}%', style: Body2.style),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScenarioExplanation extends StatelessWidget {
  const _ScenarioExplanation(
      {required this.teamName, required this.event, required this.scenarios});

  final String teamName;
  final String event;
  final List<_ScenarioViewData> scenarios;

  @override
  Widget build(BuildContext context) {
    final win = scenarios.firstWhere((item) => item.outcome == 'win');
    final loss = scenarios.firstWhere((item) => item.outcome == 'loss');
    final locale = Localizations.localeOf(context);
    var subject = teamName;
    if (locale.languageCode == 'ko') {
      // 한글 마지막 음절의 받침에 맞춰 팀 이름에 '이·가'를 붙여요.
      final last = teamName.runes.last;
      final hasFinalConsonant =
          last >= 0xAC00 && last <= 0xD7A3 && (last - 0xAC00) % 28 != 0;
      subject += hasFinalConsonant ? '이' : '가';
    }
    final probabilityKey = switch (event) {
      'league_winner' => 'title probability',
      'top_4' || 'top_four' => 'TOP 4 PROBABILITY',
      'direct_relegation' => 'RELEGATION PROBABILITY',
      'relegation_playoff' => 'relegation playoff probability',
      _ => probabilityEventTitle(event),
    };
    var probability = tr(context, probabilityKey).replaceAll('\n', ' ');
    if (locale.languageCode == 'en') probability = probability.toLowerCase();
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
              'If {team} wins, {probability} {winChange}. If they lose, it {lossChange}.',
              {
                'team': subject,
                'probability': probability,
                'winChange': _probabilityChangeLabel(context, win.delta),
                'lossChange': _probabilityChangeLabel(context, loss.delta),
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

String _probabilityChangeLabel(BuildContext context, double delta) {
  // 강등 확률은 승리하면 내려가므로 결과가 아닌 실제 증감으로 표현해요.
  final tenths = (delta * 1000).round();
  if (tenths == 0) return tr(context, 'stays the same');
  return tr(
      context,
      tenths > 0
          ? 'increases by {points} percentage points'
          : 'decreases by {points} percentage points',
      {'points': (tenths.abs() / 10).toStringAsFixed(1)});
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
      'direct_relegation' => tr(context, 'RELEGATION PROBABILITY'),
      'relegation_playoff' =>
        trUpper(context, 'relegation playoff probability'),
      _ => trUpper(context, 'Probability'),
    };
