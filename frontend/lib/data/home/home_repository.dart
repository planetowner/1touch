import 'package:onetouch/models/home_data.dart';

/// Domain-facing boundary for `GET /v1/home`.
///
/// 조회할 팀을 생략하면 최애팀을 불러와요. 조회만으로 최애팀 설정을 바꾸지 않아요.
/// 조회 팀은 팔로우 목록에 있어야 하며, 뉴스는 별도 저장소에서 불러와요.
abstract interface class HomeRepository {
  Future<HomeData> load({
    int? teamId,
    DateTime? start,
    DateTime? end,
  });
}

/// An already loaded Home response, including when it is due for refresh.
class HomeSnapshot {
  const HomeSnapshot(this.data, this.savedAt);

  final HomeData data;
  final DateTime savedAt;
}

/// Optional synchronous read for screens that can display cached Home data.
abstract interface class HomeSnapshotRepository implements HomeRepository {
  HomeSnapshot? snapshotFor({required int teamId, required DateTime month});

  Future<HomeSnapshot?> restoreFor({
    required int teamId,
    required DateTime month,
  });

  void clearSnapshots();
}
