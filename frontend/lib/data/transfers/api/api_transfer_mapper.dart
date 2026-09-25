import 'package:onetouch/data/transfers/api/api_transfer_response.dart';
import 'package:onetouch/models/team_transfer_window.dart';

TeamTransferWindow teamTransferWindowFromApiResponse(
  ApiTeamTransfersResponse response, {
  required int teamId,
}) {
  return TeamTransferWindow(
    teamId: teamId,
    windowKey: response.windowKey,
    incoming: response.transfersIn
        .map(
          (transfer) => _entryFromApiResponse(
            transfer,
            expectedDirection: TransferDirection.incoming,
          ),
        )
        .toList(),
    outgoing: response.transfersOut
        .map(
          (transfer) => _entryFromApiResponse(
            transfer,
            expectedDirection: TransferDirection.outgoing,
          ),
        )
        .toList(),
  );
}

TransferEntry _entryFromApiResponse(
  ApiTransferResponse response, {
  required TransferDirection expectedDirection,
}) {
  final direction = switch (response.direction) {
    'in' => TransferDirection.incoming,
    'out' => TransferDirection.outgoing,
    _ => throw FormatException(
        'Unsupported transfer direction "${response.direction}".',
      ),
  };
  if (direction != expectedDirection) {
    throw FormatException(
      'Transfer ${response.transferId} has direction ${response.direction} '
      'inside the ${expectedDirection.name} list.',
    );
  }

  // Other-team imagery and currency remain at the transport boundary until
  // a frontend feature has defined how it will present them.
  return TransferEntry(
    transferId: response.transferId,
    playerId: response.playerId,
    playerName: response.playerName,
    playerImage: response.playerImage,
    jerseyNumber: response.jerseyNumber,
    direction: direction,
    typeId: response.typeId,
    otherTeamId: response.otherTeamId,
    otherTeamName: response.otherTeamName,
    displayType: response.displayType,
    amount: response.amount,
    transferDate: response.transferDate,
    contractStartDate: _dateOnly(
      response.contractStartDate,
      fieldName: 'contract_start_date',
    ),
    contractEndDate: _dateOnly(
      response.contractEndDate,
      fieldName: 'contract_end_date',
    ),
  );
}

DateTime? _dateOnly(String? value, {required String fieldName}) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('Invalid transfer $fieldName "$value".');
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Invalid transfer $fieldName "$value".');
  }
  return parsed;
}
