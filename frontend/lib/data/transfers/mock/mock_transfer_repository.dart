import 'package:flutter/foundation.dart';
import 'package:onetouch/data/transfers/mock/transfer_catalog.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/models/team_transfer_window.dart';
import 'package:onetouch/models/transfer.dart';

class MockTransferRepository implements TransferRepository {
  MockTransferRepository({
    List<TeamTransfer>? transfers,
    int latestWindowId = 3,
    String windowKey = '2026 winter',
  })  : _transfers = List.unmodifiable(transfers ?? mockTransfers),
        _latestWindowId = latestWindowId,
        _windowKey = windowKey;

  final List<TeamTransfer> _transfers;
  final int _latestWindowId;
  final String _windowKey;
  final ValueNotifier<Map<int, TeamTransferWindow>> _cachedWindows =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamTransferWindow>> get cachedWindows =>
      _cachedWindows;

  @override
  TeamTransferWindow? cachedForTeam(int teamId) => _cachedWindows.value[teamId];

  @override
  Future<TeamTransferWindow> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    final incoming = <TransferEntry>[];
    final outgoing = <TransferEntry>[];
    final teamTransfers = _transfers.where(
      (transfer) =>
          transfer.windowId == _latestWindowId &&
          (transfer.fromTeamId == teamId || transfer.toTeamId == teamId),
    );

    for (final transfer in teamTransfers) {
      final isIncoming = transfer.toTeamId == teamId;
      final entry = TransferEntry(
        transferId: transfer.transferId,
        playerId: transfer.playerId,
        playerName: transfer.playerName,
        playerImage: transfer.playerImage,
        direction: isIncoming
            ? TransferDirection.incoming
            : TransferDirection.outgoing,
        otherTeamId: isIncoming ? transfer.fromTeamId : transfer.toTeamId,
        otherTeamName: isIncoming ? transfer.fromTeamName : transfer.toTeamName,
        displayType: _displayType(transfer.typeId, transfer.amount),
        amount: transfer.amount,
        transferDate: transfer.transferDate,
      );

      if (isIncoming) {
        incoming.add(entry);
      } else {
        outgoing.add(entry);
      }
    }

    incoming.sort(_compareNewestFirst);
    outgoing.sort(_compareNewestFirst);

    final window = TeamTransferWindow(
      teamId: teamId,
      windowKey: _windowKey,
      incoming: incoming,
      outgoing: outgoing,
    );
    _cachedWindows.value = Map.unmodifiable({
      ..._cachedWindows.value,
      teamId: window,
    });
    return window;
  }

  static int _compareNewestFirst(TransferEntry a, TransferEntry b) {
    final aDate = a.transferDate ?? '';
    final bDate = b.transferDate ?? '';
    final dateComparison = bDate.compareTo(aDate);
    if (dateComparison != 0) return dateComparison;
    return b.transferId.compareTo(a.transferId);
  }

  static String? _displayType(int typeId, int? amount) {
    switch (typeId) {
      case 218:
        return 'Loan';
      case 9688:
        return 'End of Loan';
      case 220:
        return 'Free Transfer';
      case 219:
        if (amount == null || amount <= 0) return 'Transfer';
        if (amount >= 1000000) {
          final millions = amount / 1000000;
          return millions == millions.roundToDouble()
              ? '€${millions.toInt()}M'
              : '€${millions.toStringAsFixed(1)}M';
        }
        if (amount >= 1000) return '€${(amount / 1000).round()}K';
        return '€$amount';
      default:
        return null;
    }
  }
}
