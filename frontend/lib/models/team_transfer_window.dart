import 'package:flutter/foundation.dart';

enum TransferDirection { incoming, outgoing }

@immutable
class TransferEntry {
  const TransferEntry({
    required this.transferId,
    required this.playerId,
    required this.direction,
    required this.typeId,
    this.playerName,
    this.playerImage,
    this.jerseyNumber,
    this.otherTeamId,
    this.otherTeamName,
    this.displayType,
    this.amount,
    this.transferDate,
    this.contractStartDate,
    this.contractEndDate,
  });

  final int transferId;
  final int playerId;
  final String? playerName;
  final String? playerImage;
  final int? jerseyNumber;
  final TransferDirection direction;
  final int typeId;
  final int? otherTeamId;
  final String? otherTeamName;
  final String? displayType;
  final int? amount;
  final String? transferDate;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
}

@immutable
class TeamTransferWindow {
  TeamTransferWindow({
    required this.teamId,
    required this.windowKey,
    required List<TransferEntry> incoming,
    required List<TransferEntry> outgoing,
  })  : incoming = List.unmodifiable(incoming),
        outgoing = List.unmodifiable(outgoing);

  final int teamId;
  final String windowKey;
  final List<TransferEntry> incoming;
  final List<TransferEntry> outgoing;
}
