import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/transfers/api/api_transfer_mapper.dart';
import 'package:onetouch/data/transfers/api/api_transfer_response.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_transfer_window.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/transfers`.
class ApiTransferRepository implements TransferRepository {
  ApiTransferRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
  final Map<int, Future<TeamTransferWindow>> _inFlightLoads = {};
  final ValueNotifier<Map<int, TeamTransferWindow>> _cachedWindows =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamTransferWindow>> get cachedWindows =>
      _cachedWindows;

  @override
  TeamTransferWindow? cachedForTeam(int teamId) => _cachedWindows.value[teamId];

  @override
  Future<TeamTransferWindow> loadForTeam(int teamId) {
    final cached = cachedForTeam(teamId);
    if (cached != null) return Future.value(cached);

    // 홈 선로딩 도중 팀 화면을 열어도 명단을 중복 요청하지 않아요.
    return _inFlightLoads[teamId] ??= _fetchAndCache(teamId).whenComplete(() {
      _inFlightLoads.remove(teamId);
    });
  }

  Future<TeamTransferWindow> _fetchAndCache(int teamId) async {
    final uri = _api.baseUri.resolve('teams/$teamId/transfers');
    final response = await _api.get(
      uri,
    );
    if (response.statusCode == 404) {
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Transfers',
      );
    }

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);

    final window = teamTransferWindowFromApiResponse(
      ApiTeamTransfersResponse.fromJson(decoded),
      teamId: teamId,
    );
    _cachedWindows.value = Map.unmodifiable({
      ..._cachedWindows.value,
      teamId: window,
    });
    return window;
  }
}
