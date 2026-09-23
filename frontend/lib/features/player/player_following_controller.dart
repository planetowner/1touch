import 'package:flutter/foundation.dart';
import 'package:onetouch/data/players/following_players_repository.dart';
import 'package:onetouch/data/players/following_players_repository_provider.dart';
import 'package:onetouch/models/following_player.dart';

final playerFollowingController = PlayerFollowingController();

class PlayerFollowingController extends ChangeNotifier {
  PlayerFollowingController({this.repository});
  final FollowingPlayersRepository? repository;
  List<FollowingPlayer> players = [];
  bool loading = false, loaded = false;
  Object? error;
  Future<void>? _request;
  FollowingPlayersRepository get _repository =>
      repository ?? followingPlayersRepository;
  bool contains(int id) => players.any((p) => p.playerId == id);

  Future<void> load() => _request ??= _load();
  Future<void> _load() async {
    loading = true;
    loaded = false;
    players = [];
    error = null;
    notifyListeners();
    try {
      players = await Future.sync(() => _repository.load());
      loaded = true;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      _request = null;
      notifyListeners();
    }
  }

  Future<void> save(Iterable<int> ids) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      // 서버가 저장한 순서를 받은 뒤 메인과 상세의 즐겨찾기를 함께 갱신해요.
      players = await _repository.replaceFollowing(ids);
      loaded = true;
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(int id) async {
    if (!loaded) await load();
    if (!loaded) throw StateError('Could not load favorites');
    await save(contains(id)
        ? players.where((p) => p.playerId != id).map((p) => p.playerId)
        : [...players.map((p) => p.playerId), id]);
  }
}
