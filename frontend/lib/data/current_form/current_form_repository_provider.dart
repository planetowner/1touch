import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/current_form/api/api_current_form_repository.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final CurrentFormRepository currentFormRepository = ApiCurrentFormRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
