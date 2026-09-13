import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/transfers/api/api_transfer_response.dart';

void main() {
  test('parses the verified team-transfers response', () {
    final response = ApiTeamTransfersResponse.fromJson({
      'window_key': '2026/2027 summer',
      'transfers_in': [_transferJson(direction: 'in')],
      'transfers_out': [_transferJson(direction: 'out', transferId: 2)],
    });

    expect(response.windowKey, '2026/2027 summer');
    expect(response.transfersIn.single.direction, 'in');
    expect(response.transfersOut.single.direction, 'out');
    expect(response.transfersIn.single.amount, 8500000);
    expect(response.transfersIn.single.contractEndDate, '2030-06-30');
  });

  test('preserves every documented nullable transfer field', () {
    final transfer = ApiTeamTransfersResponse.fromJson({
      'window_key': '2026/2027 summer',
      'transfers_in': [
        {
          ..._transferJson(direction: 'in'),
          'player_name': null,
          'player_image': null,
          'other_team_id': null,
          'other_team_name': null,
          'other_team_image': null,
          'jersey_number': null,
          'amount': null,
          'currency': null,
          'transfer_date': null,
          'contract_start_date': null,
          'contract_end_date': null,
        },
      ],
      'transfers_out': [],
    }).transfersIn.single;

    expect(transfer.playerName, isNull);
    expect(transfer.playerImage, isNull);
    expect(transfer.otherTeamId, isNull);
    expect(transfer.otherTeamName, isNull);
    expect(transfer.otherTeamImage, isNull);
    expect(transfer.jerseyNumber, isNull);
    expect(transfer.amount, isNull);
    expect(transfer.currency, isNull);
    expect(transfer.transferDate, isNull);
    expect(transfer.contractStartDate, isNull);
    expect(transfer.contractEndDate, isNull);
  });

  test('rejects malformed required, nullable, and list fields', () {
    final malformedRequired = _transferJson(direction: 'in')
      ..['display_type'] = null;
    final malformedNullable = _transferJson(direction: 'in')
      ..['jersey_number'] = '10';

    expect(
      () => ApiTeamTransfersResponse.fromJson({
        'window_key': '2026/2027 summer',
        'transfers_in': [malformedRequired],
        'transfers_out': [],
      }),
      throwsFormatException,
    );
    expect(
      () => ApiTeamTransfersResponse.fromJson({
        'window_key': '2026/2027 summer',
        'transfers_in': [malformedNullable],
        'transfers_out': [],
      }),
      throwsFormatException,
    );
    expect(
      () => ApiTeamTransfersResponse.fromJson({
        'window_key': '2026/2027 summer',
        'transfers_in': 'invalid',
        'transfers_out': [],
      }),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _transferJson({
  required String direction,
  int transferId = 1,
}) =>
    {
      'transfer_id': transferId,
      'player_id': 101,
      'player_name': 'Incoming Player',
      'player_image': 'https://example.com/player.png',
      'direction': direction,
      'other_team_id': 10,
      'other_team_name': 'Source FC',
      'other_team_image': 'https://example.com/source.png',
      'jersey_number': 10,
      'type_id': 219,
      'display_type': 'Transfer',
      'amount': 8500000,
      'currency': null,
      'transfer_date': '2026-07-01',
      'contract_start_date': '2026-07-01',
      'contract_end_date': '2030-06-30',
    };
