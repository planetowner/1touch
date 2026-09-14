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

  // The response also carries other-team imagery, jersey, currency and
  // contract metadata. Keep those values at the transport boundary until a
  // frontend feature has defined how it will present them.
  return TransferEntry(
    transferId: response.transferId,
    playerId: response.playerId,
    playerName: response.playerName,
    playerImage: response.playerImage,
    direction: direction,
    typeId: response.typeId,
    otherTeamId: response.otherTeamId,
    otherTeamName: response.otherTeamName,
    displayType: response.displayType,
    amount: response.amount,
    transferDate: response.transferDate,
  );
}
