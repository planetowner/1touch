import 'package:onetouch/models/home_data.dart';

/// Domain-facing boundary for `GET /v1/home`.
///
/// Highlights and news are intentionally excluded because the endpoint does
/// not provide them. A successful load must enforce the app invariant that the
/// favorite team exists and belongs to the followed-team list.
abstract interface class HomeRepository {
  Future<HomeData> load({
    DateTime? start,
    DateTime? end,
  });
}
