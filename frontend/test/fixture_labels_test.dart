import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import 'package:onetouch/models/fixture.dart';

void main() {
  for (final entry in {
    'en': ('Round 33', 'Semi-final · Leg 1 of 2', 'Semi-final · Leg 2 of 2'),
    'ko': ('33R', '준결승 1차전', '준결승 2차전'),
    'ja': ('第33節', 'Semi-finals • 第1戦', 'Semi-finals • 第2戦'),
    'zh': ('第33轮', 'Semi-finals • 第1回合', 'Semi-finals • 第2回合'),
  }.entries) {
    test('formats rounds and legs in ${entry.key}', () {
      final locale = Locale(entry.key);
      expect(
        fixtureRoundLabel(
          _fixture(round: '33', stage: 'Regular Season', leg: '1/1'),
          locale: locale,
        ),
        entry.value.$1,
      );
      expect(
        fixtureRoundLabel(
          _fixture(stage: 'Semi-finals', leg: '1/2'),
          locale: locale,
        ),
        entry.value.$2,
      );
      expect(
        fixtureRoundLabel(
          _fixture(stage: 'Semi-finals', leg: '2/2'),
          locale: locale,
        ),
        entry.value.$3,
      );
    });
  }

  test('prefers a named round and trims each label', () {
    expect(
      fixtureRoundLabel(
        _fixture(round: ' Quarter-finals ', stage: 'Knockout', leg: ' 2/2 '),
        locale: const Locale('en'),
      ),
      'Quarter-final · Leg 2 of 2',
    );
  });

  test('uses the knockout stage and preserves unrecognized API names', () {
    expect(
      fixtureRoundLabel(
        _fixture(round: ' ', stage: ' Final ', leg: '1/1'),
        locale: const Locale('ko'),
      ),
      '결승',
    );
    expect(
      fixtureRoundLabel(_fixture(round: 'QF'), locale: const Locale('en')),
      'QF',
    );
  });

  test('omits missing phases even when a leg is present', () {
    for (final fixture in [
      null,
      _fixture(),
      _fixture(round: ' ', stage: ' ', leg: '1/2'),
    ]) {
      expect(fixtureRoundLabel(fixture, locale: const Locale('en')), isNull);
    }
  });

  test('preserves an already named leg', () {
    expect(
      fixtureRoundLabel(
        _fixture(stage: 'Quarter-finals', leg: ' Replay '),
        locale: const Locale('en'),
      ),
      'Quarter-final · Replay',
    );
  });

  for (final raw in ['7', 'Round 7', '7th Round']) {
    test('shares numbered round formatting for $raw', () {
      expect(
          fixtureRoundLabel(_fixture(round: raw), locale: const Locale('en')),
          'Round 7');
      expect(
          fixtureRoundLabel(_fixture(round: raw), locale: const Locale('ko')),
          '7R');
    });
  }

  for (final entry in {
    '8th Finals': 16,
    'Round of 16': 16,
    '16th Finals': 32,
    'Round of 32': 32
  }.entries) {
    test('normalizes knockout stage ${entry.key}', () {
      final fixture = _fixture(stage: entry.key, leg: '1/1');
      expect(fixtureRoundLabel(fixture, locale: const Locale('en')),
          'Round of ${entry.value}');
      expect(fixtureRoundLabel(fixture, locale: const Locale('ko')),
          '${entry.value}강');
    });
  }

  const competitions = {
    2: ('Champions League', 'UEFA 챔피언스리그', 'UCL'),
    5: ('Europa League', 'UEFA 유로파리그', 'UEL'),
    2286: ('Europa Conference League', 'UEFA 컨퍼런스리그', 'UECL'),
    8: ('Premier League', '프리미어리그', 'PL'),
    82: ('Bundesliga', '분데스리가', 'BL'),
    301: ('Ligue 1', '리그 1', 'L1'),
    384: ('Serie A', '세리에 A', 'Serie A'),
    564: ('La Liga', '라리가', 'LALIGA'),
    24: ('FA Cup', 'FA컵', 'FA Cup'),
    27: ('Carabao Cup', '카라바오컵', 'EFL Cup'),
    390: ('Coppa Italia', '코파 이탈리아', 'Coppa Italia'),
    570: ('Copa Del Rey', '코파 델 레이', 'CDR'),
  };
  for (final entry in competitions.entries) {
    final (english, korean, code) = entry.value;
    final abbreviated = {2, 5, 2286}.contains(entry.key);
    test('uses the approved competition name for $english', () {
      final fixture =
          _fixture(competitionId: entry.key, round: '7', leg: '1/1');
      expect(
          formatFixtureCompetitionLabel(fixture,
              locale: const Locale('en'),
              competitionName: english,
              competitionShortCode: code),
          '${abbreviated ? code : english} · Round 7');
      expect(
          formatFixtureCompetitionLabel(fixture,
              locale: const Locale('ko'),
              competitionName: korean,
              competitionShortCode: code),
          '$korean 7R');
    });
  }

  for (final entry in [
    (
      2,
      '8th Finals',
      '1/2',
      'UCL · Round of 16 · Leg 1 of 2',
      'UEFA 챔피언스리그 16강 1차전'
    ),
    (2, 'Final', '1/1', 'UCL · Final', 'UEFA 챔피언스리그 결승'),
    (
      570,
      'Semi-finals',
      '1/2',
      'Copa Del Rey · Semi-final · Leg 1 of 2',
      '코파 델 레이 준결승 1차전'
    ),
    (
      570,
      'Semi-finals',
      '2/2',
      'Copa Del Rey · Semi-final · Leg 2 of 2',
      '코파 델 레이 준결승 2차전'
    ),
    (570, '8th Finals', '1/1', 'Copa Del Rey · Round of 16', '코파 델 레이 16강'),
    (24, 'Semi-finals', '1/1', 'FA Cup · Semi-final', 'FA컵 준결승'),
  ]) {
    test('formats ${entry.$4} from the fixture leg data', () {
      final fixture =
          _fixture(competitionId: entry.$1, stage: entry.$2, leg: entry.$3);
      final names = competitions[entry.$1]!;
      expect(
          formatFixtureCompetitionLabel(fixture,
              locale: const Locale('en'),
              competitionName: names.$1,
              competitionShortCode: names.$3),
          entry.$4);
      expect(
          formatFixtureCompetitionLabel(fixture,
              locale: const Locale('ko'),
              competitionName: names.$2,
              competitionShortCode: names.$3),
          entry.$5);
    });
  }

  test('uses only the competition when a phase is missing', () {
    expect(
        formatFixtureCompetitionLabel(_fixture(competitionId: 564),
            locale: const Locale('ko'), competitionName: '라리가'),
        '라리가');
  });

  test('requires catalog short_code for the three European competitions', () {
    expect(
        () => formatFixtureCompetitionLabel(_fixture(),
            locale: const Locale('en'), competitionName: 'Champions League'),
        throwsStateError);
  });
}

Fixture _fixture(
        {int competitionId = 2, String? round, String? stage, String? leg}) =>
    Fixture(
      fixtureId: 1,
      seasonId: 1,
      competitionId: competitionId,
      homeTeamId: 8,
      awayTeamId: 19,
      competitionType: CompetitionType.europe,
      roundName: round,
      stageName: stage,
      leg: leg,
      status: FixtureStatus.upcoming,
      startingAt: null,
    );
