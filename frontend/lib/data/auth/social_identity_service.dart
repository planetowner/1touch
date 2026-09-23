import 'package:onetouch/data/auth/login_provider.dart';

class SocialLoginCancelled implements Exception {
  const SocialLoginCancelled();
}

abstract interface class SocialIdentityService {
  Future<Map<String, String>> authenticate(LoginProvider provider);
}
