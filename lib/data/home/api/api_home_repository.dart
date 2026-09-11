import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/home/api/api_home_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/models/home_data.dart';

/// HTTP implementation of the verified `GET /v1/home` contract.
class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

  @override
  Future<HomeData> load({DateTime? start, DateTime? end}) async {
    const boundaryEnvelope = Duration(days: 1);
    final queryParameters = <String, String>{
      // The backend filters UTC database dates while Home displays device-local
      // dates. Include adjacent UTC dates so timezone-boundary fixtures are not
      // omitted; FixtureCalendar performs the final local-month filtering.
      if (start != null)
        'start': _formatDate(_dateOnly(start).subtract(boundaryEnvelope)),
      if (end != null) 'end': _formatDate(_dateOnly(end).add(boundaryEnvelope)),
    };
    final homeUri = _apiBaseUri.resolve('home');
    final uri = queryParameters.isEmpty
        ? homeUri
        : homeUri.replace(queryParameters: queryParameters);
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Home request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the Home response to be a JSON object.',
      );
    }
    return homeDataFromApiResponse(ApiHomeResponse.fromJson(decoded));
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
