import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/betting/api/api_betting_repository.dart';
import 'package:onetouch/data/betting/betting_repository.dart';

final BettingRepository bettingRepository = ApiBettingRepository(
  api: apiClient,
);
