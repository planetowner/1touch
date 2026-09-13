/// Transport response for `GET /v1/teams/{team_id}/transfers`.
class ApiTeamTransfersResponse {
  const ApiTeamTransfersResponse({
    required this.windowKey,
    required this.transfersIn,
    required this.transfersOut,
  });

  final String windowKey;
  final List<ApiTransferResponse> transfersIn;
  final List<ApiTransferResponse> transfersOut;

  factory ApiTeamTransfersResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamTransfersResponse(
      windowKey: _requiredString(json, 'window_key'),
      transfersIn: _requiredObjectList(
        json,
        'transfers_in',
        ApiTransferResponse.fromJson,
      ),
      transfersOut: _requiredObjectList(
        json,
        'transfers_out',
        ApiTransferResponse.fromJson,
      ),
    );
  }
}

class ApiTransferResponse {
  const ApiTransferResponse({
    required this.transferId,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.direction,
    required this.otherTeamId,
    required this.otherTeamName,
    required this.otherTeamImage,
    required this.jerseyNumber,
    required this.typeId,
    required this.displayType,
    required this.amount,
    required this.currency,
    required this.transferDate,
    required this.contractStartDate,
    required this.contractEndDate,
  });

  final int transferId;
  final int playerId;
  final String? playerName;
  final String? playerImage;
  final String direction;
  final int? otherTeamId;
  final String? otherTeamName;
  final String? otherTeamImage;
  final int? jerseyNumber;
  final int typeId;
  final String displayType;
  final int? amount;
  final String? currency;
  final String? transferDate;
  final String? contractStartDate;
  final String? contractEndDate;

  factory ApiTransferResponse.fromJson(Map<String, dynamic> json) {
    return ApiTransferResponse(
      transferId: _requiredInt(json, 'transfer_id'),
      playerId: _requiredInt(json, 'player_id'),
      playerName: _nullableString(json, 'player_name'),
      playerImage: _nullableString(json, 'player_image'),
      direction: _requiredString(json, 'direction'),
      otherTeamId: _nullableInt(json, 'other_team_id'),
      otherTeamName: _nullableString(json, 'other_team_name'),
      otherTeamImage: _nullableString(json, 'other_team_image'),
      jerseyNumber: _nullableInt(json, 'jersey_number'),
      typeId: _requiredInt(json, 'type_id'),
      displayType: _requiredString(json, 'display_type'),
      amount: _nullableInt(json, 'amount'),
      currency: _nullableString(json, 'currency'),
      transferDate: _nullableString(json, 'transfer_date'),
      contractStartDate: _nullableString(json, 'contract_start_date'),
      contractEndDate: _nullableString(json, 'contract_end_date'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _nullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is int) return value as int?;
  throw FormatException('Expected nullable integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Expected nullable string field "$key".');
}

List<T> _requiredObjectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('Expected each "$key" item to be a JSON object.');
      }
      return fromJson(item);
    }),
  );
}
