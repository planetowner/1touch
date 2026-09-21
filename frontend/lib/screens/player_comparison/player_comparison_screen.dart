import 'package:flutter/material.dart';
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_detail.dart';

part 'comparison_header.dart';

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
      _players.every((p) => p != null) &&
      _players[0]!.analysis?.position != null &&
      _players[0]!.analysis?.position == _players[1]!.analysis?.position;
  @override
  void initState() {
    super.initState();
    final raw = widget.initialPlayerId;
    final id = raw == null
        ? null
        : int.tryParse(raw) ?? playerRepository.findById(raw)?.externalPlayerId;
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
      setState(() => _players[slot] = player);
      // 프로필 포지션으로 추정하지 않고 선택한 시즌의 실제 최다 출전 포지션을 비교해요.
      if (other != null &&
          (position == null || position != other.analysis?.position)) {
        setState(() => _error =
            'Select a player with the same season position (${other.analysis?.position ?? 'unavailable'}).');
      }
    } on Object {
      if (mounted && request == _request) {
        setState(() => _error =
            'Could not load player data. Please select the player again.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _pick(int slot) async {
    final candidate = await showModalBottomSheet<PlayerCandidate>(
        context: context,
        isScrollControlled: true,
        builder: (_) => PlayerPickerSheet(
            repository: _repository, excludedId: _players[1 - slot]?.playerId));
    if (candidate != null && mounted) await _load(slot, candidate.id);
  }

  void _back() {
    if (_ready) {
      setState(() {
        _request++;
        _loading = false;
        _players[1] = null;
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
  Widget build(BuildContext context) => Scaffold(
      key: const ValueKey('player-comparison-scaffold'),
      backgroundColor: mainPageBackground(context),
      body: SafeArea(
          child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            _HeaderArea(
                p1: _players[0],
                p2: _players[1],
                onBack: _back,
                onSearch: () {
                  if (!_loading) _pick(_players[0] == null ? 0 : 1);
                },
                onTap1: _loading ? null : () => _pick(0),
                onTap2: _loading ? null : () => _pick(1)),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loading) const LinearProgressIndicator(),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(_error!)),
                      for (var slot = 0; slot < 2; slot++)
                        if (_players[slot] != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: PlayerSeasonSelector(
                                  key: ValueKey(
                                      'comparison-season-$slot-${_players[slot]!.selectedSeason?.id}'),
                                  detail: _players[slot]!,
                                  onChanged: (season) => _loading
                                      ? null
                                      : _load(slot, _players[slot]!.playerId,
                                          seasonId: season))),
                      if (_ready) ...[
                        Text(
                            '${_players[0]!.analysis?.position ?? '—'} · Season totals',
                            style: Body2_b.style),
                        const SizedBox(height: 16),
                        PlayerStatCategories(
                            categories: _players[0]!.analysis?.categories ?? [],
                            comparison:
                                _players[1]!.analysis?.categories ?? []),
                      ] else if (!_loading)
                        const Text(
                            'Select two players with the same season position to compare.'),
                    ])),
          ]))));
}
