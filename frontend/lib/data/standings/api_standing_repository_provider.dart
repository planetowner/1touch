import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/standings/api/api_standing_repository.dart';
import 'package:onetouch/data/standings/standing_repository.dart';

/// Staged real provider. The Standing screen will adopt this in the next step;
/// the existing `standingRepository` remains mock-backed until it awaits loads.
final StandingRepository apiStandingRepository = ApiStandingRepository(
  api: apiClient,
);
