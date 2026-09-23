import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_repository.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';

final BestElevenRepository bestElevenRepository = ApiBestElevenRepository(
  api: apiClient,
);
