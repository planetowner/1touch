import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_contract_roster.dart';

enum SortOption { position, jerseyNumber, age, contractLength, wage }

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.position:
        return 'Position';
      case SortOption.jerseyNumber:
        return 'Jersey Number';
      case SortOption.age:
        return 'Age';
      case SortOption.contractLength:
        return 'Contract Length';
      case SortOption.wage:
        return 'Wage';
    }
  }
}

enum Position { GK, DF, MF, FW }

@immutable
class SquadPlayer {
  SquadPlayer({
    required this.id,
    required this.name,
    required this.teamLabel,
    this.teamId,
    this.teamName,
    this.jerseyNumber,
    this.position,
    this.age,
    this.imageUrl,
    DateTime? contractEndDate,
    this.estimatedWeeklyGrossEur,
    this.leadershipRole,
    int? contractEndYear,
  })  : assert(
          contractEndDate == null || contractEndYear == null,
          'Provide either contractEndDate or the mock contractEndYear.',
        ),
        contractEndDate = contractEndDate ??
            (contractEndYear == null
                ? null
                : DateTime.utc(contractEndYear, 12, 31));

  final int id;
  final String name;
  final String teamLabel;
  final int? teamId;
  final String? teamName;
  final int? jerseyNumber;
  final Position? position;
  final int? age;
  final String? imageUrl;
  final DateTime? contractEndDate;
  final int? estimatedWeeklyGrossEur;
  final TeamLeadershipRole? leadershipRole;

  factory SquadPlayer.fromContract(
    TeamPlayerContract contract, {
    required String teamName,
    int? teamId,
    required DateTime asOf,
  }) {
    return SquadPlayer(
      id: contract.playerId,
      name: contract.playerName,
      teamId: teamId,
      teamName: teamName,
      teamLabel: contract.jerseyNumber == null
          ? teamName
          : '$teamName • ${contract.jerseyNumber}',
      jerseyNumber: contract.jerseyNumber,
      position: positionFromTeamGroup(contract.positionGroup),
      age: ageAt(contract.dateOfBirth, asOf),
      imageUrl: contract.playerImage,
      contractEndDate: contract.endDate,
      estimatedWeeklyGrossEur: contract.estimatedWeeklyGrossEur,
      leadershipRole: contract.leadershipRole,
    );
  }
}

Position? positionFromTeamGroup(TeamPositionGroup? positionGroup) {
  switch (positionGroup) {
    case TeamPositionGroup.goalkeeper:
      return Position.GK;
    case TeamPositionGroup.defender:
      return Position.DF;
    case TeamPositionGroup.midfielder:
      return Position.MF;
    case TeamPositionGroup.forward:
      return Position.FW;
    case null:
      return null;
  }
}

int? ageAt(DateTime? dateOfBirth, DateTime asOf) {
  if (dateOfBirth == null) return null;

  var age = asOf.year - dateOfBirth.year;
  final birthdayHasOccurred = asOf.month > dateOfBirth.month ||
      (asOf.month == dateOfBirth.month && asOf.day >= dateOfBirth.day);
  if (!birthdayHasOccurred) age--;
  return age;
}

List<SortOption> availableSquadSortOptions({required bool isCurrent}) {
  return SortOption.values
      .where((option) => isCurrent || option != SortOption.contractLength)
      .toList(growable: false);
}

int compareSquadPlayers(
  SquadPlayer a,
  SquadPlayer b, {
  required SortOption option,
  required bool ascending,
}) {
  int result;
  switch (option) {
    case SortOption.position:
      result = _compareNullable(
        a.position == null ? null : Position.values.indexOf(a.position!),
        b.position == null ? null : Position.values.indexOf(b.position!),
        ascending: ascending,
      );
      if (result != 0) return result;
      return _compareNullable(
        a.jerseyNumber,
        b.jerseyNumber,
        ascending: ascending,
      );
    case SortOption.jerseyNumber:
      return _compareNullable(
        a.jerseyNumber,
        b.jerseyNumber,
        ascending: ascending,
      );
    case SortOption.age:
      return _compareNullable(a.age, b.age, ascending: ascending);
    case SortOption.contractLength:
      return _compareNullable(
        a.contractEndDate,
        b.contractEndDate,
        ascending: ascending,
      );
    case SortOption.wage:
      return _compareNullable(
        a.estimatedWeeklyGrossEur,
        b.estimatedWeeklyGrossEur,
        ascending: ascending,
      );
  }
}

int _compareNullable<T extends Comparable<dynamic>>(
  T? a,
  T? b, {
  required bool ascending,
}) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  final result = a.compareTo(b);
  return ascending ? result : -result;
}
