import 'package:flutter/widgets.dart';
import 'package:onetouch/data/catalog/football_names.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/l10n/app_localizations.dart' show tr;

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
        : leaguePositionLabel(
            context,
            competitionNameLabel(
                context, team!.competitionId, team.competitionName!),
            team.currentPosition,
            missingPositionLabel: null,
          );

String leaguePositionLabel(
  BuildContext context,
  String leagueName,
  int? position, {
  String? missingPositionLabel = '-',
}) {
  // 홈에서는 순위가 없으면 '-'를, 팀 헤더와 목록에서는 리그명만 보여줘요.
  if (position == null) {
    return missingPositionLabel == null
        ? leagueName
        : '$leagueName $missingPositionLabel';
  }
  final rank = Localizations.localeOf(context).languageCode == 'en'
      ? _englishOrdinal(position)
      : tr(context, '{rank} place', {'rank': position});
  return '$leagueName $rank';
}

String _englishOrdinal(int number) {
  final lastTwoDigits = number % 100;
  if (lastTwoDigits >= 11 && lastTwoDigits <= 13) return '${number}th';
  final suffix = switch (number % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
  return '$number$suffix';
}
