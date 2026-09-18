import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/team_attributes/team_attribute_baseline.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository_provider.dart';
import 'package:onetouch/features/team/attributes/team_attribute_radar.dart';
import 'package:onetouch/models/team_attribute_scores.dart';

class MatchAttributeComparison extends StatefulWidget {
  const MatchAttributeComparison({
    super.key,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.repository,
  });

  final int homeTeamId;
  final int awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final TeamAttributeRepository? repository;

  @override
  State<MatchAttributeComparison> createState() =>
      _MatchAttributeComparisonState();
}

class _MatchAttributeComparisonState extends State<MatchAttributeComparison> {
  TeamAttributeScores? _home;
  TeamAttributeScores? _away;
  bool _loading = true;
  bool _failed = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MatchAttributeComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeTeamId != widget.homeTeamId ||
        oldWidget.awayTeamId != widget.awayTeamId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _home = null;
      _away = null;
      _loading = true;
      _failed = false;
    });
    try {
      final repository = widget.repository ?? teamAttributeRepository;
      final results = await Future.wait([
        loadTeamAttributeBaseline(repository, widget.homeTeamId),
        loadTeamAttributeBaseline(repository, widget.awayTeamId),
      ]);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _home = results[0].scores.firstOrNull;
        _away = results[1].scores.firstOrNull;
        _loading = false;
      });
    } on Object {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATTRIBUTES', style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppPalette.black
                : AppPalette.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: _loading
              ? const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _failed
                  ? TextButton(
                      onPressed: _load,
                      child: const Text('능력치를 불러오지 못했어요. 다시 시도'),
                    )
                  : _home == null || _away == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child:
                              Text('아직 준비중이에요ㅠㅠ', textAlign: TextAlign.center),
                        )
                      : TeamAttributeRadar(
                          scores: _home!, comparisonScores: _away),
        ),
        if (!_loading && !_failed && _home != null && _away != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _legend(const Color(0xFFE8434A), widget.homeTeamName)),
              const SizedBox(width: 12),
              Expanded(child: _legend(foreground, widget.awayTeamName)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _legend(Color color, String name) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(name.toUpperCase(), style: Body2_b.style, maxLines: 2),
          ),
        ],
      );
}
