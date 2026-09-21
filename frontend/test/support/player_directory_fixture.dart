import 'package:flutter/foundation.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/data/players/following_players_repository.dart';
import 'package:onetouch/models/following_player.dart';

class FakePlayerDirectoryRepository implements PlayerDirectoryRepository {
  final calls = <({int? league, String? position, int offset})>[];
  bool fail = false;
  @override
  Future<PlayerRankingPage> ranking(
      {int? league, String? position, int offset = 0}) async {
    calls.add((league: league, position: position, offset: offset));
    if (fail) throw StateError('offline');
    return PlayerRankingPage(
        season: '2026/2027',
        leagues: const [
          (id: 8, name: 'Premier League', available: 7),
          (id: 82, name: 'Bundesliga', available: 0)
        ],
        total: league == 82 ? 0 : 7,
        items: league == 82
            ? []
            : List.generate(
                7,
                (i) => (
                      id: i + 1,
                      name: 'Ranked player ${i + 1}',
                      image: null,
                      position: position ?? 'FW',
                      rank: i + 1,
                      score: 91.2 - i,
                      rating: 8.1 - i / 10,
                      appearances: 7
                    )));
  }

  @override
  Future<List<PlayerWatch>> watch() async {
    if (fail) throw StateError('offline');
    return [
      (
        id: 1,
        name: 'Improving player',
        image: null,
        recent: 8.4,
        previous: 6.2,
        change: 2.2
      )
    ];
  }
}

class FakeFollowingPlayersRepository implements FollowingPlayersRepository {
  final players = ValueNotifier<List<FollowingPlayer>>([
    const FollowingPlayer(playerId: 1, name: 'Favorite player', imagePath: null)
  ]);
  List<int>? saved;
  bool fail = false;
  @override
  ValueListenable<List<FollowingPlayer>> get cachedPlayers => players;
  @override
  Future<List<FollowingPlayer>> load() async {
    if (fail) throw StateError('offline');
    return players.value;
  }

  @override
  Future<List<FollowingPlayer>> replaceFollowing(Iterable<int> ids) async {
    if (fail) throw StateError('offline');
    saved = ids.toList();
    players.value = ids
        .map((id) => FollowingPlayer(
            playerId: id, name: 'Saved player $id', imagePath: null))
        .toList();
    return players.value;
  }
}
