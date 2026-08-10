import 'package:flutter/foundation.dart';

@immutable
class TeamCompetitionContext {
  const TeamCompetitionContext({
    required this.teamId,
    this.competitionId,
    this.competitionName,
    this.currentPosition,
  });

  final int teamId;
  final int? competitionId;
  final String? competitionName;
  final int? currentPosition;

  String get label {
    final name = competitionName;
    if (name == null) return '';

    final position = currentPosition;
    if (position == null) return name;

    final suffix = switch (position) {
      1 => '1st',
      2 => '2nd',
      3 => '3rd',
      _ => '${position}th',
    };
    return '$name $suffix';
  }
}

abstract interface class TeamCompetitionContextResolver {
  TeamCompetitionContext? resolve(int teamId);
}

extension TeamCompetitionContextResolverLabel
    on TeamCompetitionContextResolver {
  String labelFor(int teamId) => resolve(teamId)?.label ?? '';
}
