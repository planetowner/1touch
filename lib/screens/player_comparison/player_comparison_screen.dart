import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/models/player.dart';

part 'comparison_card.dart';
part 'comparison_header.dart';
part 'comparison_mock_data.dart';
part 'comparison_models.dart';
part 'comparison_picker_sheets.dart';
part 'comparison_stats.dart';
part 'radar_chart.dart';

class PlayerComparisonScreen extends StatefulWidget {
  /// Pass a player ID only when entering from a specific player page.
  final String? initialPlayerId;

  const PlayerComparisonScreen({super.key, this.initialPlayerId});

  @override
  State<PlayerComparisonScreen> createState() => _PlayerComparisonScreenState();
}

class _PlayerComparisonScreenState extends State<PlayerComparisonScreen> {
  late final ScrollController _scrollController;

  ComparisonPlayer? _p1;
  ComparisonPlayer? _p2;
  String? _s1;
  String? _s2;

  bool get _bothReady => _p1 != null && _p2 != null;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectInitialPlayer();
  }

  void _selectInitialPlayer() {
    final initialPlayerId = widget.initialPlayerId;
    if (initialPlayerId == null) return;

    _p1 = _findById(initialPlayerId);
    _s1 = _latestSeason(_p1);
  }

  String? _latestSeason(ComparisonPlayer? player) {
    if (player == null || player.clubSeasons.isEmpty) return null;
    return player.clubSeasons.values.first.last;
  }

  void _openPlayerPicker(int slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerPickerSheet(
        slot: slot,
        excludedId: slot == 1 ? _p2?.id : _p1?.id,
        onPick: (player) {
          Navigator.pop(context);
          _openSeasonPicker(slot, player);
        },
      ),
    );
  }

  void _openSeasonPicker(int slot, ComparisonPlayer player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeasonPickerSheet(
        player: player,
        onPick: (season) {
          Navigator.pop(context);
          setState(() {
            if (slot == 1) {
              _p1 = player;
              _s1 = season;
            } else {
              _p2 = player;
              _s2 = season;
            }
          });
        },
      ),
    );
  }

  void _selectPair(ComparisonPlayer p1, ComparisonPlayer p2) {
    setState(() {
      _p1 = p1;
      _s1 = _latestSeason(p1);
      _p2 = p2;
      _s2 = _latestSeason(p2);
    });
  }

  void _handleBack() {
    if (!_bothReady) {
      if (Navigator.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/players');
      }
      return;
    }

    setState(() {
      _p2 = null;
      _s2 = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const ValueKey('player-comparison-scaffold'),
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : AppPalette.lightModeDarkGrey,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderArea(
                  p1: _p1,
                  p2: _p2,
                  s1: _s1,
                  s2: _s2,
                  onBack: _handleBack,
                  onSearch: () => context.push('/search'),
                  onTap1: () => _openPlayerPicker(1),
                  onTap2: () => _openPlayerPicker(2),
                ),
                if (_bothReady)
                  _ComparisonContent(p1: _p1!, p2: _p2!)
                else
                  _MostComparedSection(onTapPair: _selectPair),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
