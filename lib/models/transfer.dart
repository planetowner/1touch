// transfer_id | player_id | player_name | player_image
// from_team_id | from_team_name | to_team_id | to_team_name
// type_id | type_name | amount | transfer_date | window_id
// created_at | updated_at

enum TransferType { transfer, loan }

class TeamTransfer {
  final int transferId;
  final int playerId;
  final String playerName;
  final String playerImage;

  final int fromTeamId;
  final String fromTeamName;
  final int toTeamId;
  final String toTeamName;

  final int typeId;
  final TransferType typeName; // 218=loan, 219=transfer
  final int? amount; // null for loans
  final String transferDate; // 'YYYY-MM-DD'
  final int windowId;

  final String createdAt;
  final String updatedAt;

  const TeamTransfer({
    required this.transferId,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.fromTeamId,
    required this.fromTeamName,
    required this.toTeamId,
    required this.toTeamName,
    required this.typeId,
    required this.typeName,
    this.amount,
    required this.transferDate,
    required this.windowId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeamTransfer.fromJson(Map<String, dynamic> json) {
    return TeamTransfer(
      transferId: json['transfer_id'] as int,
      playerId: json['player_id'] as int,
      playerName: json['player_name'] as String,
      playerImage: json['player_image'] as String,
      fromTeamId: json['from_team_id'] as int,
      fromTeamName: json['from_team_name'] as String,
      toTeamId: json['to_team_id'] as int,
      toTeamName: json['to_team_name'] as String,
      typeId: json['type_id'] as int,
      typeName: (json['type_id'] as int) == 218
          ? TransferType.loan
          : TransferType.transfer,
      amount: json['amount'] as int?,
      transferDate: json['transfer_date'] as String,
      windowId: json['window_id'] as int,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}
