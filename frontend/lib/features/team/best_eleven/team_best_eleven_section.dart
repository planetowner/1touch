import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/team_best_eleven.dart';

import 'package:onetouch/l10n/app_localizations.dart';
part 'best_eleven_formation_filter.dart';
part 'best_eleven_painters.dart';
part 'best_eleven_pitch.dart';

enum TeamBestElevenVariant { overview, analysis }

class TeamBestElevenSection extends StatefulWidget {
  const TeamBestElevenSection({
    super.key,
    required this.teamId,
    required this.variant,
    this.repository,
    this.onUnavailable,
  });

  final int? teamId;
  final TeamBestElevenVariant variant;
  final BestElevenRepository? repository;
  final VoidCallback? onUnavailable;

  @override
  State<TeamBestElevenSection> createState() => _TeamBestElevenSectionState();
}

class _TeamBestElevenSectionState extends State<TeamBestElevenSection> {
  TeamBestEleven? _lineup;
  List<BestElevenFormationOption> _formations = const [];
  String? _selectedFormation;
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _isUnavailable = false;
  int _loadRequestId = 0;

  BestElevenRepository get _repository =>
      widget.repository ?? bestElevenRepository;

  @override
  void initState() {
    super.initState();
    _startDefaultLoad();
  }

  @override
  void didUpdateWidget(TeamBestElevenSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.teamId != oldWidget.teamId ||
        widget.repository != oldWidget.repository ||
        widget.variant != oldWidget.variant) {
      _startDefaultLoad();
    }
  }

  void _startDefaultLoad() {
    final teamId = widget.teamId;
    final requestId = ++_loadRequestId;
    final cached = teamId == null ? null : _repository.cachedForTeam(teamId);

    _lineup = cached;
    _formations = cached?.formations ?? const [];
    _selectedFormation = cached?.formation;
    _isLoading = teamId != null && cached == null;
    _loadFailed = false;
    _isUnavailable = false;

    if (_isLoading) {
      unawaited(_loadLineup(teamId!, requestId));
    }
  }

  Future<void> _loadLineup(
    int teamId,
    int requestId, {
    String? formation,
  }) async {
    try {
      final lineup = await _repository.loadForTeam(
        teamId,
        formation: formation,
      );
      if (!mounted || requestId != _loadRequestId) return;
      final isUnavailable = lineup == null && widget.onUnavailable != null;
      setState(() {
        _lineup = lineup;
        if (lineup != null) {
          _formations = lineup.formations;
          _selectedFormation = lineup.formation;
        }
        _isLoading = false;
        _isUnavailable = isUnavailable;
      });
      if (isUnavailable) widget.onUnavailable?.call();
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _changeFormation(String formation) {
    final teamId = widget.teamId;
    if (teamId == null || formation == _selectedFormation) return;

    final requestId = ++_loadRequestId;
    final cached = _repository.cachedForTeam(teamId, formation: formation);
    setState(() {
      _selectedFormation = formation;
      _lineup = cached;
      if (cached != null) _formations = cached.formations;
      _isLoading = cached == null;
      _loadFailed = false;
    });

    if (cached == null) {
      unawaited(_loadLineup(teamId, requestId, formation: formation));
    }
  }

  void _retryLoad() {
    final teamId = widget.teamId;
    if (teamId == null) return;

    final requestId = ++_loadRequestId;
    final formation = _selectedFormation;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    unawaited(_loadLineup(teamId, requestId, formation: formation));
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.variant) {
      TeamBestElevenVariant.overview => _buildOverview(),
      TeamBestElevenVariant.analysis => _buildAnalysis(),
    };
  }

  Widget _buildOverview() {
    if (widget.teamId == null) return const SizedBox.shrink();

    if (_isUnavailable) {
      return const SizedBox.shrink(
        key: ValueKey('best-eleven-unavailable'),
      );
    }

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox.square(
            key: ValueKey('best-eleven-loading'),
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_loadFailed) {
      return Padding(
        key: const ValueKey('best-eleven-error'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(tr(context, 'Unable to load best eleven'),
                  style: Body2.style),
            ),
            TextButton(
                onPressed: _retryLoad, child: Text(tr(context, 'RETRY'))),
          ],
        ),
      );
    }

    final players = _lineup?.players ?? const <BestElevenEntry>[];
    if (players.isEmpty) {
      return Padding(
        key: const ValueKey('best-eleven-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child:
            Text(tr(context, 'No best eleven available'), style: Body2.style),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: BestElevenPitch(teamId: widget.teamId!, players: players),
    );
  }

  Widget _buildAnalysis() {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BestElevenSectionHeader(
            title: tr(context, 'BEST ELEVEN'),
            trailing: _formations.isEmpty
                ? null
                : _BestElevenFormationFilter(
                    formations: _formations,
                    selectedFormation: _selectedFormation,
                    enabled: !_isLoading,
                    appColors: appColors,
                    colors: colors,
                    onChanged: _changeFormation,
                  ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox.square(
                  key: ValueKey('analysis-best-eleven-loading'),
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_loadFailed)
            Row(
              key: const ValueKey('analysis-best-eleven-error'),
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Unable to load best eleven'),
                    style: Body2.style,
                  ),
                ),
                TextButton(
                    onPressed: _retryLoad, child: Text(tr(context, 'RETRY'))),
              ],
            )
          else if (_lineup == null || _lineup!.players.isEmpty)
            Padding(
              key: const ValueKey('analysis-best-eleven-empty'),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(tr(context, 'No best eleven available'),
                  style: Body2.style),
            )
          else
            BestElevenPitch(
              teamId: widget.teamId!,
              players: _lineup!.players,
            ),
        ],
      ),
    );
  }
}

class _BestElevenSectionHeader extends StatelessWidget {
  const _BestElevenSectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final control = trailing;
    if (control == null) return Text(tr(context, title), style: Body2_b.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, title), style: Body2_b.style),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: control),
            ],
          );
        }

        return Row(
          children: [
            Text(tr(context, title), style: Body2_b.style),
            const SizedBox(width: 12),
            const Spacer(),
            control,
          ],
        );
      },
    );
  }
}
