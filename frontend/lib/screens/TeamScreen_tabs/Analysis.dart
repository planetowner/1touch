import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/current_form/current_form_repository_provider.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/models/current_form.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';

part 'analysis/analysis_shared.dart';
part 'analysis/attributes_section.dart';
part 'analysis/current_form_section.dart';
part 'analysis/current_form_chart_painters.dart';
part 'analysis/probability_section.dart';

class AnalysisTab extends StatelessWidget {
  final Map<String, dynamic>? team;
  final TeamAttributeRepository? repository;

  const AnalysisTab({
    super.key,
    required this.team,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttributesSection(team: team, repository: repository),
          ProbabilitySection(),
          TeamBestElevenSection(
            teamId: team?['id'] as int?,
            variant: TeamBestElevenVariant.analysis,
          ),
          CurrentFormSection(team: team),
        ],
      ),
    );
  }
}
