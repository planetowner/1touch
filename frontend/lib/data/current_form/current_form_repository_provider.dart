import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/current_form/api/api_current_form_repository.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final CurrentFormRepository currentFormRepository = ApiCurrentFormRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
