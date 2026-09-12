import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/transfers/mock/mock_transfer_repository.dart';
import 'package:onetouch/models/transfer.dart';

import 'support/transfer_repository_contract.dart';

void main() {
  group('MockTransferRepository contract', () {
    transferRepositoryContract(
      createRepository: () => MockTransferRepository(
        transfers: const [
          TeamTransfer(
            transferId: 1,
            playerId: 101,
            playerName: 'Incoming Player',
            playerImage: 'incoming.png',
            fromTeamId: 10,
            fromTeamName: 'Source FC',
            toTeamId: 9,
            toTeamName: 'Target FC',
            typeId: 219,
            typeName: TransferType.transfer,
            amount: 8500000,
            transferDate: '2026-01-10',
            windowId: 3,
            createdAt: '2026-01-10 00:00:00',
            updatedAt: '2026-01-10 00:00:00',
          ),
          TeamTransfer(
            transferId: 2,
            playerId: 102,
            playerName: 'Outgoing Player',
            playerImage: 'outgoing.png',
            fromTeamId: 9,
            fromTeamName: 'Source FC',
            toTeamId: 20,
            toTeamName: 'Destination FC',
            typeId: 218,
            typeName: TransferType.loan,
            amount: null,
            transferDate: '2026-01-20',
            windowId: 3,
            createdAt: '2026-01-20 00:00:00',
            updatedAt: '2026-01-20 00:00:00',
          ),
          TeamTransfer(
            transferId: 3,
            playerId: 103,
            playerName: 'Free Player',
            playerImage: 'free.png',
            fromTeamId: 30,
            fromTeamName: 'Free FC',
            toTeamId: 9,
            toTeamName: 'Target FC',
            typeId: 220,
            typeName: TransferType.transfer,
            amount: 0,
            transferDate: '2026-01-25',
            windowId: 3,
            createdAt: '2026-01-25 00:00:00',
            updatedAt: '2026-01-25 00:00:00',
          ),
          TeamTransfer(
            transferId: 4,
            playerId: 104,
            playerName: 'Registered Player',
            playerImage: 'registered.png',
            fromTeamId: 9,
            fromTeamName: 'Same Team',
            toTeamId: 9,
            toTeamName: 'Same Team',
            typeId: 219,
            typeName: TransferType.transfer,
            amount: 0,
            transferDate: '2026-01-30',
            windowId: 3,
            createdAt: '2026-01-30 00:00:00',
            updatedAt: '2026-01-30 00:00:00',
          ),
          TeamTransfer(
            transferId: 5,
            playerId: 105,
            playerName: 'Old Window Player',
            playerImage: 'old.png',
            fromTeamId: 40,
            fromTeamName: 'Old FC',
            toTeamId: 9,
            toTeamName: 'Target FC',
            typeId: 219,
            typeName: TransferType.transfer,
            amount: 1000000,
            transferDate: '2025-08-10',
            windowId: 2,
            createdAt: '2025-08-10 00:00:00',
            updatedAt: '2025-08-10 00:00:00',
          ),
        ],
      ),
    );
  });

  test('wraps the existing latest-window mock transfer catalog', () async {
    final repository = MockTransferRepository();
    final window = await repository.loadForTeam(9);

    expect(window.incoming, hasLength(2));
    expect(window.outgoing, hasLength(4));
  });
}
