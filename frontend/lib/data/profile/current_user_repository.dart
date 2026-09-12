import 'package:onetouch/models/current_user_profile.dart';

abstract interface class CurrentUserRepository {
  Future<CurrentUserProfile> load();
}
