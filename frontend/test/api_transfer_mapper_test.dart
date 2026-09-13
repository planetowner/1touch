import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/transfers/api/api_transfer_mapper.dart';
import 'package:onetouch/data/transfers/api/api_transfer_response.dart';
import 'package:onetouch/models/team_transfer_window.dart';

void main() {
  test('maps backend transfer groups without changing their order', () {
    final response = ApiTeamTransfersResponse.fromJson({
      'window_key': '2026/2027 summer',
      'transfers_in': [
        _transferJson(transferId: 2, direction: 'in'),
        _transferJson(transferId: 1, direction: 'in'),
      ],
      'transfers_out': [
        _transferJson(transferId: 3, direction: 'out'),
      ],
    });

    final window = teamTransferWindowFromApiResponse(response, teamId: 83);

    expect(window.teamId, 83);
    expect(window.windowKey, '2026/2027 summer');
    expect(window.incoming.map((entry) => entry.transferId), [2, 1]);
    expect(window.incoming.first.direction, TransferDirection.incoming);
    expect(window.outgoing.single.direction, TransferDirection.outgoing);
    expect(window.incoming.first.displayType, 'Transfer');
    expect(() => window.incoming.clear(), throwsUnsupportedError);
  });

  test('rejects unknown and incorrectly grouped directions', () {
    final unknown = ApiTeamTransfersResponse.fromJson({
      'window_key': '2026/2027 summer',
      'transfers_in': [_transferJson(transferId: 1, direction: 'unknown')],
      'transfers_out': [],
    });
    final wrongGroup = ApiTeamTransfersResponse.fromJson({
      'window_key': '2026/2027 summer',
      'transfers_in': [_transferJson(transferId: 2, direction: 'out')],
      'transfers_out': [],
    });

    expect(
      () => teamTransferWindowFromApiResponse(unknown, teamId: 83),
      throwsFormatException,
    );
    expect(
      () => teamTransferWindowFromApiResponse(wrongGroup, teamId: 83),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _transferJson({
  required int transferId,
  required String direction,
}) =>
    {
      'transfer_id': transferId,
      'player_id': 100 + transferId,
      'player_name': 'Player $transferId',
      'player_image': null,
      'direction': direction,
      'other_team_id': 10,
      'other_team_name': 'Other Team',
      'other_team_image': null,
      'jersey_number': null,
      'type_id': 219,
      'display_type': 'Transfer',
      'amount': null,
      'currency': null,
      'transfer_date': '2026-07-01',
      'contract_start_date': null,
      'contract_end_date': null,
    };
