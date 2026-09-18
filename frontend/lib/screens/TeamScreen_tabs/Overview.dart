import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';

class OverviewTab extends StatefulWidget {
  final Map<String, dynamic>? team;
  final ValueChanged<int>? onStandingCompetitionSelected;
  final BestElevenRepository? bestElevenRepository;
  final TeamInjuryRepository? injuryRepository;
  final StandingRepository? standingRepository;
  final TransferRepository? transferRepository;

  const OverviewTab({
    super.key,
    required this.team,
    this.onStandingCompetitionSelected,
    this.bestElevenRepository,
    this.injuryRepository,
    this.standingRepository,
    this.transferRepository,
  });

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  bool _showBestElevenSection = true;
  bool _showInjurySection = true;
  bool _showTransferSection = true;

  int? get _teamId => widget.team?['id'] as int?;

  @override
  void didUpdateWidget(OverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team?['id'] != _teamId) {
      _showBestElevenSection = true;
      _showInjurySection = true;
      _showTransferSection = true;
    }
  }

  void _hideBestElevenSection() {
    if (!_showBestElevenSection || !mounted) return;
    setState(() => _showBestElevenSection = false);
  }

  void _hideInjurySection() {
    if (!_showInjurySection || !mounted) return;
    setState(() => _showInjurySection = false);
  }

  void _hideTransferSection() {
    if (!_showTransferSection || !mounted) return;
    setState(() => _showTransferSection = false);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final hasStanding = widget.team?['standing'] != null;
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 24),
              const SectionHeader(title: "FIXTURE"),
              // Pass the whole team map
              Fixtures(teams: widget.team),

              if (hasStanding) ...[
                const SizedBox(height: 32),
                const SectionHeader(title: "STANDING"),
                Standing(
                  teams: widget.team,
                  onCompetitionSelected: widget.onStandingCompetitionSelected,
                  repository: widget.standingRepository,
                ),
              ],

              if (_showBestElevenSection) ...[
                const SizedBox(height: 32),
                const SectionHeader(title: "BEST XI"),
                TeamBestElevenSection(
                  teamId: _teamId,
                  variant: TeamBestElevenVariant.overview,
                  repository: widget.bestElevenRepository,
                  onUnavailable: _hideBestElevenSection,
                ),
              ],

              if (_showInjurySection) ...[
                const SizedBox(height: 32),
                const SectionHeader(title: "INJURY STATUS"),
                InjuryStatus(
                  teams: widget.team,
                  repository: widget.injuryRepository,
                  onUnavailable: _hideInjurySection,
                ),
              ],

              if (_showTransferSection) ...[
                const SizedBox(height: 20),
                const SectionHeader(title: "TRANSFERS"),
                Transfer(
                  teams: widget.team,
                  repository: widget.transferRepository,
                  onUnavailable: _hideTransferSection,
                ),
              ],

              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  height: 108,
                  decoration: ShapeDecoration(
                    color: isLight ? AppPalette.black : AppPalette.lightGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "Ad",
                      textAlign: TextAlign.center,
                      style: Heading4.style.copyWith(color: AppPalette.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(title, style: Body1_b.style, textAlign: TextAlign.start),
    );
  }
}
