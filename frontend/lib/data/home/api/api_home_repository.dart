import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/viewer_country_config.dart';
import 'package:onetouch/data/home/api/api_home_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/models/home_data.dart';

/// HTTP implementation of the verified `GET /v1/home` contract.
class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository({
    required ApiClient api,
    required String viewerCountry,
  })  : _api = api,
        _viewerCountry = ViewerCountryConfig.normalize(viewerCountry);

  final ApiClient _api;
  final String _viewerCountry;

  @override
  Future<HomeData> load({int? teamId, DateTime? start, DateTime? end}) async {
    const boundaryEnvelope = Duration(days: 1);
    final queryParameters = <String, String>{
      'viewer_country': _viewerCountry,
      if (teamId != null) 'team_id': '$teamId',
      // The backend filters UTC database dates while Home displays device-local
      // dates. Include adjacent UTC dates so timezone-boundary fixtures are not
      // omitted; FixtureCalendar performs the final local-month filtering.
      if (start != null)
        'start': _formatDate(_dateOnly(start).subtract(boundaryEnvelope)),
      if (end != null) 'end': _formatDate(_dateOnly(end).add(boundaryEnvelope)),
    };
    final homeUri = _api.baseUri.resolve('home');
    final uri = queryParameters.isEmpty
        ? homeUri
        : homeUri.replace(queryParameters: queryParameters);
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final apiResponse = ApiHomeResponse.fromJson(decoded);
    final responseCountry = apiResponse.highlights?.viewerCountry;
    if (responseCountry != null && responseCountry != _viewerCountry) {
      throw FormatException(
        'Expected highlight viewer_country $_viewerCountry but received '
        '$responseCountry.',
      );
    }
    return homeDataFromApiResponse(apiResponse);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
