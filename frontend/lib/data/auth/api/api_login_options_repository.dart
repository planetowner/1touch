import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/auth/login_provider.dart';

class ApiLoginOptionsRepository {
  const ApiLoginOptionsRepository({required this.api});
  final ApiClient api;

  Future<LoginOptions> load({required String platform, String? country}) async {
    final uri = api.baseUri.resolve('auth/providers').replace(queryParameters: {
      'platform': platform,
      if (country != null && country.isNotEmpty) 'country_code': country,
    });
    final response = await api.get(uri);
    return LoginOptions.fromJson(
        api.decodeJson<Map<String, dynamic>>(response));
  }
}
