import 'package:flutter/foundation.dart';
import 'package:onetouch/models/team_transfer_window.dart';

abstract interface class TransferRepository {
  ValueListenable<Map<int, TeamTransferWindow>> get cachedWindows;

  TeamTransferWindow? cachedForTeam(int teamId);

  Future<TeamTransferWindow> loadForTeam(int teamId);
}
