import 'package:flutter/widgets.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';

class FootballNamesScope extends InheritedWidget {
  const FootballNamesScope({
    super.key,
    required this.names,
    required super.child,
  });

  final FootballNames names;

  static FootballNames of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FootballNamesScope>()?.names ??
      const FootballNames();

  @override
  bool updateShouldNotify(FootballNamesScope oldWidget) =>
      names != oldWidget.names;
}

// short_code는 언어와 무관한 식별 표기라 이 함수로 번역하지 않아요.
String teamNameLabel(BuildContext context, int? id, String original,
        {bool short = false}) =>
    FootballNamesScope.of(context).team(id, original, short: short);

String playerNameLabel(BuildContext context, int? id, String original,
        {bool short = false}) =>
    FootballNamesScope.of(context).player(id, original, short: short);

String countryNameLabel(BuildContext context, int? id, String original) =>
    FootballNamesScope.of(context).country(id, original);

String coachNameLabel(BuildContext context, int? id, String original) =>
    FootballNamesScope.of(context).coach(id, original);

String normalizeCompetitionDisplayLabel(String label) => label.replaceAll(
      RegExp(r'\bLA\s*LIGA\b', caseSensitive: false),
      'LA LIGA',
    );

String competitionNameLabel(BuildContext context, int? id, String original) =>
    normalizeCompetitionDisplayLabel(
      FootballNamesScope.of(context).competition(id, original),
    );

String competitionShortNameLabel(
    BuildContext context, int? id, String original) {
  final shortCode = footballCatalog.competitions.value
      .where((competition) => competition.competitionId == id)
      .firstOrNull
      ?.shortCode
      ?.trim();
  if (shortCode != null && shortCode.isNotEmpty) {
    return normalizeCompetitionDisplayLabel(shortCode);
  }
  return competitionNameLabel(context, id, original);
}

String teamCompetitionLabel(
        BuildContext context, TeamCompetitionContext? team) =>
    team?.competitionName == null
        ? ''
        : team!.labelWithCompetitionName(
            competitionNameLabel(
                context, team.competitionId, team.competitionName!),
          );
