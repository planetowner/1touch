import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/standings/api/api_xg_standing_repository.dart';
import 'package:onetouch/data/standings/xg_standing_repository.dart';

/// Real query provider used by the xG branch of the standings screen. The
/// legacy `xgStandingRepository` remains mock-backed for catalog consumers.
final XgStandingRepository apiXgStandingRepository = ApiXgStandingRepository(
  api: apiClient,
);
