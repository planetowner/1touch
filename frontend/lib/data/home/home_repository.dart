import 'package:onetouch/models/home_data.dart';

/// Domain-facing boundary for `GET /v1/home`.
///
/// Official highlights are part of this aggregate. News remains outside it
/// because the backend does not provide a news contract. A successful load
/// must enforce the app invariant that the favorite team exists and belongs to
/// the followed-team list.
abstract interface class HomeRepository {
  Future<HomeData> load({
    DateTime? start,
    DateTime? end,
  });
}
