import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_detail.dart';

part 'comparison_header.dart';
part 'comparison_picker_sheets.dart';
part 'comparison_stats.dart';
part 'radar_chart.dart';

class PlayerComparisonScreen extends StatefulWidget {
  const PlayerComparisonScreen(
      {super.key, this.initialPlayerId, this.repository});
  final String? initialPlayerId;
  final PlayerDetailRepository? repository;

  @override
  State<PlayerComparisonScreen> createState() => _PlayerComparisonScreenState();
}

class _PlayerComparisonScreenState extends State<PlayerComparisonScreen> {
  final List<PlayerDetail?> _players = [null, null];
  bool _loading = false;
  String? _error;
  int _request = 0;

  PlayerDetailRepository get _repository =>
      widget.repository ?? playerDetailRepository;
  bool get _ready =>
      _players.every((player) => player != null) &&
      _players[0]!.analysis?.position != null &&
      _players[0]!.analysis?.position == _players[1]!.analysis?.position;

  @override
  void initState() {
    super.initState();
    final raw = widget.initialPlayerId;
    final id = raw == null
        ? null
        : int.tryParse(raw);
    if (id != null) _load(0, id);
  }

  Future<void> _load(int slot, int id, {int? seasonId}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final player = await _repository.load(id, seasonId: seasonId);
      if (!mounted || request != _request) return;
      final other = _players[1 - slot];
      final position = player.analysis?.position;
      setState(() {
        _players[slot] = player;
        if (other != null &&
            (position == null || position != other.analysis?.position)) {
          _error =
              'Select a player with the same season position (${other.analysis?.position ?? 'unavailable'}).';
        }
      });
    } on Object {
      if (mounted && request == _request) {
        setState(() => _error =
            'Could not load player data. Please select the player again.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _pickPlayer(int slot) async {
    final player = await showModalBottomSheet<PlayerDetail>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComparisonPlayerPickerSheet(
        slot: slot + 1,
        repository: _repository,
        excludedId: _players[1 - slot]?.playerId,
        requiredPosition: _players[1 - slot]?.analysis?.position,
      ),
    );
    if (player == null || !mounted) return;
    if (player.seasons.isEmpty) {
      setState(() => _players[slot] = player);
      return;
    }
    final seasonId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComparisonSeasonPickerSheet(player: player),
    );
    if (seasonId != null && mounted) {
      await _load(slot, player.playerId, seasonId: seasonId);
    }
  }

  void _back() {
    if (_ready) {
      setState(() {
        _request++;
        _loading = false;
        _players[1] = null;
        _error = null;
      });
      return;
    }
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/players');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      key: const ValueKey('player-comparison-scaffold'),
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : AppPalette.lightModeDarkGrey,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderArea(
                  p1: _players[0],
                  p2: _players[1],
                  onBack: _back,
                  onSearch: () => context.push('/search'),
                  onTap1: _loading ? null : () => _pickPlayer(0),
                  onTap2: _loading ? null : () => _pickPlayer(1),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (_ready)
                  _ComparisonContent(p1: _players[0]!, p2: _players[1]!)
                else if (!_loading)
                  const _MostComparedUnavailableSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MostComparedUnavailableSection extends StatelessWidget {
  const _MostComparedUnavailableSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 31, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MOST COMPARED',
            style: TextStyle(
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: appCardShadows(context),
            ),
            child: Text(
              '아직 준비중이에요ㅠㅠ',
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

Color _teamPrimary(PlayerDetail? player) {
  final id = player?.profile.teamId;
  final repositoryColor =
      id == null ? null : teamRepository.findById(id)?.primaryColor;
  return TeamComparisonColorResolver.paletteFor(
    teamName: player?.profile.teamName,
    primaryFallback: repositoryColor == null ? null : Color(repositoryColor),
  ).primary;
}

TeamComparisonColors _comparisonColors(
  BuildContext context,
  PlayerDetail? first,
  PlayerDetail? second,
) {
  final background = Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0A0A0A)
      : AppPalette.lightModeDarkGrey;
  return TeamComparisonColorResolver.resolve(
    anchorTeamName: first?.profile.teamName,
    anchorPrimaryFallback: _teamPrimary(first),
    opponentTeamName: second?.profile.teamName,
    opponentPrimaryFallback: _teamPrimary(second),
    background: background,
  );
}
