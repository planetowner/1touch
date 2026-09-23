import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/current_form/api/api_current_form_repository.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';

final CurrentFormRepository currentFormRepository = ApiCurrentFormRepository(
  api: apiClient,
);
