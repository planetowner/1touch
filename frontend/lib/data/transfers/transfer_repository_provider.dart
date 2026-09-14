import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/transfers/api/api_transfer_repository.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final TransferRepository transferRepository = ApiTransferRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
