import 'package:onetouch/data/players/mock/player_catalog_25_26.dart';
import 'package:onetouch/data/players/player_repository.dart';
import 'package:onetouch/models/player.dart';

class MockPlayerRepository implements PlayerRepository {
  final List<Player> _players;

  MockPlayerRepository({List<Player>? players})
      : _players = List.unmodifiable(players ?? mockPlayerCatalog2526);

  @override
  List<Player> get allPlayers => _players;

  @override
  Player? findById(String id) {
    final normalized = id.toLowerCase().trim();
    for (final player in _players) {
      if (player.id == normalized) return player;
    }
    return null;
  }

  @override
  List<Player> search(String query) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return _players;
    return _players
        .where((player) => player.searchableText.contains(normalized))
        .toList(growable: false);
  }

  @override
  List<Player> byLeague(String leagueName) => _players
      .where(
        (player) => player.leagueName.toLowerCase() == leagueName.toLowerCase(),
      )
      .toList(growable: false);

  @override
  List<Player> byPosition(PlayerPosition position) => _players
      .where((player) => player.positions.contains(position))
      .toList(growable: false);

  @override
  List<Player> get favorites =>
      _players.where((player) => player.isFavorite).toList(growable: false);

  @override
  List<Player> get onesToWatch =>
      _players.where((player) => player.isOneToWatch).toList(growable: false);

  @override
  List<Player> get ranking {
    final ranked = [..._players]
      ..sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
    return List.unmodifiable(ranked);
  }

  @override
  List<PlayerMatchSummary> recentMatchesFor(String playerId) {
    final player = findById(playerId);
    if (player == null) return const [];

    final stats = player.seasonStats;
    final firstGoals = stats.goals > 20 ? 2 : (stats.goals > 0 ? 1 : 0);
    final firstAssists = stats.assists > 10 ? 1 : 0;
    return [
      PlayerMatchSummary(
        result: 'WIN',
        score: firstGoals > 1 ? '3 - 1' : '2 - 0',
        competition: '${player.leagueCode} / Round 38',
        opponent: 'League opponent',
        goals: firstGoals,
        assists: firstAssists,
        passes: (stats.passes / stats.appearances).round(),
        rating: (stats.rating + 0.4).clamp(0, 10),
      ),
      PlayerMatchSummary(
        result: 'DRAW',
        score: '1 - 1',
        competition: '${player.leagueCode} / Round 37',
        opponent: 'League opponent',
        goals: stats.goals > 10 ? 1 : 0,
        assists: stats.assists > 5 ? 1 : 0,
        passes: (stats.passes / stats.appearances * 0.9).round(),
        rating: stats.rating,
      ),
      PlayerMatchSummary(
        result: 'WIN',
        score: '2 - 1',
        competition: '${player.leagueCode} / Round 36',
        opponent: 'League opponent',
        goals: 0,
        assists: stats.assists > 0 ? 1 : 0,
        passes: (stats.passes / stats.appearances * 1.1).round(),
        rating: (stats.rating - 0.2).clamp(0, 10),
      ),
    ];
  }
}

final PlayerRepository playerRepository = MockPlayerRepository();
