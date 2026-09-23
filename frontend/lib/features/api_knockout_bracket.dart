import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/competitions/tournament_bracket_repository.dart';

class ApiKnockoutBracket extends StatefulWidget {
  const ApiKnockoutBracket(
      {super.key,
      required this.competitionId,
      required this.seasonId,
      this.currentTeamId,
      this.repository});
  final int competitionId, seasonId;
  final int? currentTeamId;
  final TournamentBracketRepository? repository;
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
        oldWidget.repository != widget.repository) _load();
  }

  void _load() => _bracket = (widget.repository ?? tournamentBracketRepository)
      .load(widget.competitionId, widget.seasonId);

  @override
  Widget build(BuildContext context) => FutureBuilder<TournamentBracket>(
        future: _bracket,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Column(children: [
              const Text('Unable to load bracket.'),
              TextButton(
                  onPressed: () => setState(_load), child: const Text('Retry')),
            ]);
          final bracket = snapshot.requireData;
          if (bracket.status == 'not_published' || bracket.stages.isEmpty) {
            return const Center(
                child: Text('Bracket has not been published yet.'));
          }
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final stage in bracket.stages)
                    SizedBox(
                        width: 260,
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              Text(stage.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              for (final tie in stage.ties)
                                Card(
                                    child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(children: [
                                          for (final (index, slot)
                                              in tie.slots.indexed)
                                            Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                child: Row(children: [
                                                  Expanded(
                                                      child: Text(slot.label,
                                                          style: TextStyle(
                                                              fontWeight: slot
                                                                          .teamId ==
                                                                      widget
                                                                          .currentTeamId
                                                                  ? FontWeight
                                                                      .bold
                                                                  : FontWeight
                                                                      .normal))),
                                                  if (slot.teamId != null &&
                                                      slot.teamId ==
                                                          tie.winnerTeamId)
                                                    const Icon(Icons.check,
                                                        size: 16),
                                                  if (tie.aggregateScore !=
                                                      null)
                                                    Text(
                                                        ' ${tie.aggregateScore![index]}'),
                                                ])),
                                          // 팀이 정해지기 전의 슬롯도 서버가 보낸 이름으로 표시해요.
                                          for (final (index, match)
                                              in tie.matches.indexed)
                                            TextButton(
                                              onPressed: match.detailAvailable
                                                  ? () => context.push(
                                                      '/match/${match.id}')
                                                  : null,
                                              child: Text(
                                                  'Match ${index + 1} · ${match.homeScore ?? '—'} : ${match.awayScore ?? '—'}'),
                                            ),
                                        ]))),
                            ]))),
                ],
              ));
        },
      );
}
