import 'package:onetouch/core/page_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/team/draw_team_logos.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_probability.dart';

class TeamProbabilityWhatIfScreen extends StatefulWidget {
  const TeamProbabilityWhatIfScreen({
    super.key,
    required this.snapshot,
    required this.event,
    required this.teamPrimaryColor,
    this.europeanFixture,
    this.homeTeam,
    this.awayTeam,
  });

  final TeamProbabilitySnapshot snapshot;
  final String event;
  final Color teamPrimaryColor;
  final Fixture? europeanFixture;
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
    final europeanFixture = widget.europeanFixture;
    final fixture = europeanFixture == null
        ? (whatIf == null ? null : _DisplayedFixture.fromWhatIf(whatIf.fixture))
        : _DisplayedFixture.fromFixture(europeanFixture);
    final colors = AppColors.of(context);
    final contentTop = appBarContentTop(context);
    if (fixture == null) {
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
    final focusTeam = fixture.homeTeamId == widget.snapshot.teamId
        ? widget.homeTeam
        : widget.awayTeam;
    final focusTeamName = teamNameLabel(context, widget.snapshot.teamId,
        focusTeam?.displayName ?? widget.snapshot.teamName,
        short: true);
    final scenarios = <_ScenarioViewData>[
      for (final outcome in const ['win', 'draw', 'loss'])
        if (_findScenario(whatIf?.scenarios ?? const [], outcome)
            case final scenario?)
          if (_findEvent(scenario.events, widget.event) case final event?)
            _ScenarioViewData(
              outcome: outcome,
              probability: event.probability,
              delta: event.probability - (currentEvent?.probability ?? 0),
            ),
    ];
    final europeanWhatIf = widget.snapshot.europeanTitle?.whatIf;
    // 다른 경기를 예측한 확률을 현재 경기의 결과로 보여주지 않아요.
    final europeanScenarios = europeanFixture != null &&
            europeanWhatIf?.fixtureId == europeanFixture.fixtureId
        ? [
            for (final outcome in const ['win', 'draw', 'loss'])
              for (final scenario in europeanWhatIf!.scenarios)
                if (scenario.outcome == outcome)
                  _ScenarioViewData(
                    outcome: scenario.outcome,
                    probability: scenario.probability,
                    delta: scenario.changePercentagePoints == null
                        ? null
                        : scenario.changePercentagePoints! / 100,
                  ),
          ]
        : <_ScenarioViewData>[];
    // 승리와 패배의 변화량이 모두 있을 때만 결과 안내를 보여줘요.
    final hasEuropeanChangeExplanation = europeanScenarios
            .any((item) => item.outcome == 'win' && item.delta != null) &&
        europeanScenarios
            .any((item) => item.outcome == 'loss' && item.delta != null);

    return Scaffold(
      key: const ValueKey('team-probability-what-if-screen'),
      backgroundColor: mainPageBackground(context),
      body: ListView(
        padding:
            EdgeInsets.fromLTRB(24, contentTop, 24, pageContentBottomSpacing),
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
            fixture: fixture,
            teamId: widget.snapshot.teamId,
            homeTeam: widget.homeTeam,
            awayTeam: widget.awayTeam,
            selectedOutcome: _selectedOutcome,
            onSelected: (outcome) => setState(() => _selectedOutcome = outcome),
          ),
          const SizedBox(height: 48),
          Text(_eventSectionTitle(context, widget.event), style: Body2_b.style),
          const SizedBox(height: 16),
          if (europeanFixture != null && europeanScenarios.isNotEmpty) ...[
            _ScenarioChart(
              scenarios: europeanScenarios,
              color: widget.teamPrimaryColor,
              selectedOutcome: _selectedOutcome,
            ),
            if (hasEuropeanChangeExplanation) ...[
              const SizedBox(height: 16),
              _ScenarioExplanation(
                teamName: focusTeamName,
                event: widget.event,
                scenarios: europeanScenarios,
              ),
            ],
          ] else if (europeanFixture == null && scenarios.length == 3) ...[
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
                tr(
                    context,
                    europeanFixture == null
                        ? 'What-if data is unavailable for this outcome.'
                        : 'Not ready yet'),
                style: Body1.style,
              ),
            ),
        ],
      ),
    );
  }
}

class _DisplayedFixture {
  const _DisplayedFixture({
    required this.homeTeamId,
    required this.awayTeamId,
    required this.startingAt,
    required this.roundName,
    this.leg,
    this.isEuropeanFinal = false,
    this.homeName,
    this.awayName,
    this.homeShortName,
    this.awayShortName,
    this.homeLogo,
    this.awayLogo,
  });

  factory _DisplayedFixture.fromWhatIf(TeamProbabilityWhatIfFixture fixture) =>
      _DisplayedFixture(
        homeTeamId: fixture.homeTeamId,
        awayTeamId: fixture.awayTeamId,
        startingAt: fixture.startingAt,
        roundName: fixture.roundName,
      );

  factory _DisplayedFixture.fromFixture(Fixture fixture) => _DisplayedFixture(
        homeTeamId: fixture.homeTeamId,
        awayTeamId: fixture.awayTeamId,
        startingAt: fixture.kickoff!,
        roundName: fixture.roundOrStageName,
        leg: fixture.leg,
        isEuropeanFinal: fixture.competitionType == CompetitionType.europe &&
            fixture.roundOrStageName?.trim().toLowerCase() == 'final',
        homeName: fixture.homeTeamName,
        awayName: fixture.awayTeamName,
        homeShortName: fixture.homeTeamShortName,
        awayShortName: fixture.awayTeamShortName,
        homeLogo: fixture.homeTeamLogo,
        awayLogo: fixture.awayTeamLogo,
      );

  final int homeTeamId;
  final int awayTeamId;
  final DateTime startingAt;
  final String? roundName;
  final String? leg;
  final bool isEuropeanFinal;
  final String? homeName;
  final String? awayName;
  final String? homeShortName;
  final String? awayShortName;
  final String? homeLogo;
  final String? awayLogo;
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
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                fixedSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.centerLeft,
              ),
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
    required this.fixture,
    required this.teamId,
    required this.homeTeam,
    required this.awayTeam,
    required this.selectedOutcome,
    required this.onSelected,
  });

  final _DisplayedFixture fixture;
  final int teamId;
  final Team? homeTeam;
  final Team? awayTeam;
  final String? selectedOutcome;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final outcomes = fixture.isEuropeanFinal
        ? const ['win', 'loss']
        : const ['win', 'draw', 'loss'];
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
                  child: _TeamIdentity(
                      team: homeTeam,
                      id: fixture.homeTeamId,
                      fallbackName: fixture.homeName,
                      fallbackLogo: fixture.homeLogo)),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                child: _FixtureTime(
                  roundName: fixture.roundName,
                  leg: fixture.leg,
                  startingAt: fixture.startingAt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: _TeamIdentity(
                      team: awayTeam,
                      id: fixture.awayTeamId,
                      fallbackName: fixture.awayName,
                      fallbackLogo: fixture.awayLogo)),
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
                  for (var index = 0; index < outcomes.length; index++) ...[
                    _OutcomeOption(
                      outcome: outcomes[index],
                      teamId: teamId,
                      fixture: fixture,
                      homeTeam: homeTeam,
                      awayTeam: awayTeam,
                      onTap: onSelected,
                    ),
                    if (index < outcomes.length - 1)
                      Divider(height: 1, color: colors.divider),
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
  const _TeamIdentity({
    required this.team,
    required this.id,
    this.fallbackName,
    this.fallbackLogo,
  });

  final Team? team;
  final int id;
  final String? fallbackName;
  final String? fallbackLogo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TeamLogo(url: team?.imagePath ?? fallbackLogo, size: 72),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 82),
          child: Text(
            key: ValueKey('what-if-team-name-$id'),
            teamNameLabel(
                context, id, team?.displayName ?? fallbackName ?? 'Team $id',
                short: true),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Body1.style,
          ),
        ),
      ],
    );
  }
}

class _FixtureTime extends StatelessWidget {
  const _FixtureTime(
      {required this.roundName, required this.leg, required this.startingAt});

  final String? roundName;
  final String? leg;
  final DateTime startingAt;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final roundLabel = formatRoundLabel(roundName: roundName, locale: locale);
    final parts = leg?.trim().split('/');
    final legNumber = parts?.length == 2 ? int.tryParse(parts![0]) : null;
    final totalLegs = parts?.length == 2 ? int.tryParse(parts![1]) : null;
    // 단판 경기는 차전을 숨기고, 두 경기로 나뉘면 단계 아래에 따로 표시해요.
    final legLabel = legNumber != null && totalLegs != null
        ? totalLegs <= 1
            ? null
            : locale.languageCode == 'en'
                ? '${legNumber == 1 ? '1st' : legNumber == 2 ? '2nd' : '${legNumber}th'} Leg'
                : tr(context, '{leg} Leg', {'leg': legNumber})
        : leg?.trim().isNotEmpty == true
            ? leg!.trim()
            : null;
    return Column(
      children: [
        if (roundLabel != null)
          Text(roundLabel, textAlign: TextAlign.center, style: Body1.style),
        if (legLabel != null)
          Text(legLabel, textAlign: TextAlign.center, style: Body1.style),
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
  final _DisplayedFixture fixture;
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
    final selectedIsHome = selectedTeamId == fixture.homeTeamId;
    final selectedName = selectedIsHome
        ? (fixture.homeShortName ?? fixture.homeName)
        : (fixture.awayShortName ?? fixture.awayName);
    final selectedLogo = selectedIsHome ? fixture.homeLogo : fixture.awayLogo;
    final label = outcome == 'draw'
        ? teamScreenLabel(context, 'Draw')
        : tr(context, '{team} Win', {
            'team': selectedTeam?.shortCode ??
                teamNameLabel(
                    context,
                    selectedTeamId,
                    selectedTeam?.displayName ??
                        selectedName ??
                        tr(context, 'Team'),
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
              selectedLogo: selectedLogo,
              homeLogo: fixture.homeLogo,
              awayLogo: fixture.awayLogo,
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
    this.selectedLogo,
    this.homeLogo,
    this.awayLogo,
  });

  final String outcome;
  final Team? homeTeam;
  final Team? awayTeam;
  final Team? selectedTeam;
  final String? selectedLogo;
  final String? homeLogo;
  final String? awayLogo;

  @override
  Widget build(BuildContext context) {
    if (outcome != 'draw') {
      return _TeamLogo(url: selectedTeam?.imagePath ?? selectedLogo, size: 48);
    }
    return SizedBox(
      width: 48,
      height: 48,
      child: DrawTeamLogos(
        keyPrefix: 'what-if-draw',
        homeLogo: _TeamLogo(url: homeTeam?.imagePath ?? homeLogo, size: 36),
        awayLogo: _TeamLogo(url: awayTeam?.imagePath ?? awayLogo, size: 36),
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
  final double? probability;
  final double? delta;
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
    // 유효한 시나리오 중 가장 높은 확률을 막대 높이 100%로 삼아요.
    final maxProbability = scenarios
        .map((item) => item.probability ?? 0)
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
                heightFactor:
                    maxProbability == 0 || scenarios[index].probability == null
                        ? 0
                        : scenarios[index].probability! / maxProbability,
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
    final positive = (data.delta ?? 0) >= 0;
    final value = data.probability == null
        ? '–'
        : '${(data.probability! * 100).round()}%';
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (data.probability == null) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: Text(value, style: Body1.style),
                );
              }
              final valueHeight = (TextPainter(
                text: TextSpan(text: value, style: Body1.style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout(maxWidth: constraints.maxWidth))
                  .height;
              final availableBarHeight = constraints.maxHeight > valueHeight + 8
                  ? constraints.maxHeight - valueHeight - 8
                  : 0.0;
              // 숫자는 막대 높이와 함께 움직이고, 둘 사이는 항상 8px로 둬요.
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    value,
                    key: ValueKey('what-if-scenario-value-${data.outcome}'),
                    style: Body1.style,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    // 0%도 막대 위치가 보이도록 최소 높이를 4%로 둬요.
                    height: availableBarHeight * heightFactor.clamp(.04, 1),
                    width: double.infinity,
                    child: DecoratedBox(
                      key: ValueKey('what-if-scenario-bar-${data.outcome}'),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(tr(context, _outcomeLabelKey(data.outcome)),
            textAlign: TextAlign.center, style: Body2_b.style),
        const SizedBox(height: 4),
        if (data.delta == null)
          Text('–', style: Body2.style)
        else
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
                Text('${(data.delta!.abs() * 100).round()}%',
                    style: Body2.style),
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
      'ucl_winner' || 'uel_winner' || 'uecl_winner' => 'title probability',
      'top_4' || 'top_four' => 'TOP 4 PROBABILITY',
      'direct_relegation' => 'RELEGATION PROBABILITY',
      'relegation_playoff' => 'relegation playoff probability',
      _ => probabilityEventTitle(event),
    };
    var probability = tr(context, probabilityKey).replaceAll('\n', ' ');
    if (locale.languageCode == 'en') probability = probability.toLowerCase();
    return Row(
      key: const ValueKey('what-if-scenario-explanation'),
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
                'winChange': _probabilityChangeLabel(context, win.delta!),
                'lossChange': _probabilityChangeLabel(context, loss.delta!),
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
      'ucl_winner' => tr(context, 'UCL WINNER PROBABILITY'),
      'uel_winner' => tr(context, 'UEL WINNER PROBABILITY'),
      'uecl_winner' => tr(context, 'UECL WINNER PROBABILITY'),
      'top_four' || 'top_4' => tr(context, 'TOP 4 PROBABILITY'),
      'direct_relegation' => tr(context, 'RELEGATION PROBABILITY'),
      'relegation_playoff' =>
        trUpper(context, 'relegation playoff probability'),
      _ => trUpper(context, 'Probability'),
    };
