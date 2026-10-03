import 'package:flutter/widgets.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';

const _abbreviatedCompetitionIds = {2, 5, 2286};

// 일본어·중국어는 표기 규칙을 확정하기 전까지 각 화면의 기존 문구를 사용해요.
String? fixtureCompetitionLabel(BuildContext context, Fixture? fixture,
    {String? competitionName}) {
  final locale = Localizations.localeOf(context);
  if (fixture == null || !{'en', 'ko'}.contains(locale.languageCode)) {
    return null;
  }
  return competitionRoundLabel(context,
      competitionId: fixture.competitionId,
      competitionName: competitionName,
      roundName: fixture.roundName,
      stageName: fixture.stageName,
      leg: fixture.leg);
}

// 확률 예측의 다음 경기도 일반 경기와 같은 대회·라운드 표기를 써요.
String competitionRoundLabel(BuildContext context,
    {required int competitionId,
    String? competitionName,
    String? roundName,
    String? stageName,
    String? leg}) {
  final competition = competitionRepository.findById(competitionId);
  return _formatCompetitionRoundLabel(
    competitionId: competitionId,
    roundName: roundName,
    stageName: stageName,
    leg: leg,
    locale: Localizations.localeOf(context),
    competitionName: competitionNameLabel(context, competitionId,
        competition?.name ?? competitionName ?? 'Unknown'),
    competitionShortCode: competition?.shortCode,
  );
}

String formatFixtureCompetitionLabel(
  Fixture fixture, {
  required Locale locale,
  required String competitionName,
  String? competitionShortCode,
}) =>
    _formatCompetitionRoundLabel(
      competitionId: fixture.competitionId,
      roundName: fixture.roundName,
      stageName: fixture.stageName,
      leg: fixture.leg,
      locale: locale,
      competitionName: competitionName,
      competitionShortCode: competitionShortCode,
    );

String _formatCompetitionRoundLabel({
  required int competitionId,
  String? roundName,
  String? stageName,
  String? leg,
  required Locale locale,
  required String competitionName,
  String? competitionShortCode,
}) {
  var name = normalizeCompetitionDisplayLabel(competitionName);
  if (locale.languageCode == 'en' &&
      _abbreviatedCompetitionIds.contains(competitionId)) {
    if (competitionShortCode == null || competitionShortCode.trim().isEmpty) {
      throw StateError('Competition $competitionId requires short_code.');
    }
    name = normalizeCompetitionDisplayLabel(competitionShortCode);
  }
  final round = formatRoundLabel(
      roundName: roundName, stageName: stageName, leg: leg, locale: locale);
  return [name, if (round != null) round].join(_separator(locale));
}

// 경기 단계와 차전은 모든 화면에서 같은 규칙으로 표시해요.
String? fixtureRoundLabel(Fixture? fixture, {required Locale locale}) =>
    formatRoundLabel(
        roundName: fixture?.roundName,
        stageName: fixture?.stageName,
        leg: fixture?.leg,
        locale: locale);

String? formatRoundLabel(
    {String? roundName,
    String? stageName,
    String? leg,
    required Locale locale}) {
  final round = roundName?.trim();
  final stage = stageName?.trim();
  final hasRound = round != null && round.isNotEmpty;
  final phase = hasRound ? round : stage;
  if (phase == null || phase.isEmpty) return null;

  final approvedLocale = {'en', 'ko'}.contains(locale.languageCode);
  final phaseLabel = approvedLocale
      ? _phaseLabel(phase, locale)
      : hasRound && int.tryParse(round) != null
          ? translateMessage(locale, 'Round {round}', {'round': round})
          : phase;
  final legLabel = _fixtureLegLabel(leg, locale);
  return [phaseLabel, if (legLabel != null) legLabel].join(_separator(locale));
}

String _separator(Locale locale) => switch (locale.languageCode) {
      'en' => ' · ',
      'ko' => ' ',
      _ => ' • ',
    };

String _phaseLabel(String phase, Locale locale) {
  final korean = locale.languageCode == 'ko';
  final numberedRound = RegExp(r'^(?:Round )?(\d+)$').firstMatch(phase) ??
      RegExp(r'^(\d+)(?:st|nd|rd|th) Round$').firstMatch(phase);
  if (numberedRound != null) {
    final number = numberedRound.group(1)!;
    return korean ? '${number}R' : 'Round $number';
  }

  final roundOf = RegExp(r'^Round of (\d+)$').firstMatch(phase);
  final fractionalFinal =
      RegExp(r'^(\d+)(?:st|nd|rd|th) Finals$').firstMatch(phase);
  // 공급자의 8th Finals·16th Finals는 각각 16강·32강을 뜻해요.
  final teams = roundOf != null
      ? int.parse(roundOf.group(1)!)
      : fractionalFinal != null
          ? int.parse(fractionalFinal.group(1)!) * 2
          : null;
  if (teams != null) return korean ? '$teams강' : 'Round of $teams';

  // 경기 상태의 Final(경기 종료)과 대진 단계의 Final(결승)을 구분해요.
  return switch (phase) {
    'Quarter-finals' ||
    'Quarterfinals' ||
    'Quarter-final' =>
      korean ? '8강' : 'Quarter-final',
    'Semi-finals' || 'Semi-final' => korean ? '준결승' : 'Semi-final',
    'Final' => korean ? '결승' : 'Final',
    'Knockout Round Play-offs' => korean ? '녹아웃 플레이오프' : phase,
    'Preliminary Round' => korean ? '예비 라운드' : phase,
    _ => phase,
  };
}

String? _fixtureLegLabel(String? raw, Locale locale) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final parts = value.split('/');
  if (parts.length == 2) {
    final current = int.tryParse(parts[0]);
    final total = int.tryParse(parts[1]);
    if (current != null && total != null) {
      // 단판 경기의 '1/1'은 차전 문구를 붙이지 않아요.
      if (total <= 1) return null;
      if (locale.languageCode == 'en') return 'Leg $current of $total';
      return translateMessage(locale, '{leg} Leg', {'leg': current});
    }
  }
  return value;
}
