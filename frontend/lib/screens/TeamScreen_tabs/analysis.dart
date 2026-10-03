import 'dart:async';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import 'package:onetouch/data/team_attributes/team_attribute_baseline.dart';
import 'package:onetouch/features/team/attributes/team_attribute_radar.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';
import 'package:onetouch/core/app_search_field.dart';
import 'package:onetouch/core/app_close_header.dart';
import 'package:onetouch/core/probability_display.dart';
import 'package:onetouch/core/season_label.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/current_form/current_form_repository_provider.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository_provider.dart';
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/team_probability/team_probability_repository_provider.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/data/teams/team_color_palette_2627.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/features/team/probability/probability_number.dart';
import 'package:onetouch/models/current_form.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_attribute_season_option.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/screens/TeamProbabilityScreen.dart';

part 'analysis/analysis_shared.dart';
part 'analysis/comparison_filter_sheet.dart';
part 'analysis/attributes_section.dart';
part 'analysis/current_form_section.dart';
part 'analysis/current_form_chart_painters.dart';
part 'analysis/probability_section.dart';

class AnalysisTab extends StatelessWidget {
  final TeamOverview? team;
  final TeamAttributeRepository? repository;
  final TeamProbabilityRepository? probabilityRepository;
  final CurrentFormRepository? currentFormRepository;

  const AnalysisTab({
    super.key,
    required this.team,
    this.repository,
    this.probabilityRepository,
    this.currentFormRepository,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttributesSection(team: team, repository: repository),
          ProbabilitySection(
            teamId: team?.id,
            repository: probabilityRepository,
          ),
          TeamBestElevenSection(
            teamId: team?.id,
            variant: TeamBestElevenVariant.analysis,
          ),
          CurrentFormSection(team: team, repository: currentFormRepository),
        ],
      ),
    );
  }
}
