import 'package:onetouch/models/home_data.dart';

/// Domain-facing boundary for `GET /v1/home`.
///
/// Highlights and news are intentionally excluded because the endpoint does
/// not provide them.
abstract interface class HomeRepository {
  Future<HomeData> load({
    DateTime? start,
    DateTime? end,
  });
}
