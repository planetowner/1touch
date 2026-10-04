import 'package:http/http.dart' as http;

class ApiException extends http.ClientException {
  ApiException({required this.statusCode, Uri? uri})
      : super('API request failed with status $statusCode.', uri);

  final int statusCode;
}

int statusCodeForApiError(Object? error) =>
    error is ApiException ? error.statusCode : 500;
