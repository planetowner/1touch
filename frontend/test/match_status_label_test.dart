import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onetouch/features/match_info/match_status_label.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/fixture_labels.dart';
import 'package:onetouch/l10n/match_status_labels.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_clock.dart';

void main() {
  final observed = DateTime.utc(2026, 9, 24, 20);
  const en = Locale('en');
  const ko = Locale('ko');

  test('completed states share Full Time without changing the Final round', () {
    for (final state in [5, 7, 8]) {
      final fixture = _fixture(state, status: FixtureStatus.past);
      expect(matchStatusLabel(fixture, locale: en), 'Full Time');
      expect(matchStatusLabel(fixture, locale: ko), '경기 종료');
      expect(fixtureRoundLabel(fixture, locale: ko), '결승');
    }
    expect(
        matchStatusLabel(
            _fixture(15, status: FixtureStatus.past, name: 'Abandoned'),
            locale: en),
        'Abandoned');
  });

  test('uses cumulative mm:ss in English and period minutes in Korean', () {
    final sample = _clock(observed, minute: 63, second: 31);
    expect(
        matchStatusLabel(_fixture(22),
            locale: en, clock: sample, now: observed),
        '63:31');
    expect(
        matchStatusLabel(_fixture(22),
            locale: ko, clock: sample, now: observed),
        "후반 18'");
    expect(
        matchStatusLabel(_fixture(22),
            locale: en,
            clock: sample,
            now: observed.add(const Duration(seconds: 29))),
        '64:00');
    expect(
        matchStatusLabel(_fixture(22),
            locale: ko,
            clock: sample,
            now: observed.add(const Duration(seconds: 29))),
        "후반 19'");
    expect(
        matchStatusLabel(_fixture(2),
            locale: ko,
            clock: _clock(observed, minute: 18, from: 0),
            now: observed),
        "전반 18'");
    expect(
        matchStatusLabel(_fixture(22),
            locale: ko, clock: _clock(observed, minute: 93), now: observed),
        "후반 48'");
  });

  test('extra time uses the actual state even with a combined provider period',
      () {
    for (final (state, minute, expected) in [
      (6, 93, "연장 전반 3'"),
      (23, 108, "연장 후반 3'"),
    ]) {
      final sample = _clock(observed, minute: minute, from: 90, period: 3);
      expect(
          matchStatusLabel(_fixture(state),
              locale: ko, clock: sample, now: observed),
          expected);
      expect(
          matchStatusLabel(_fixture(state),
              locale: en, clock: sample, now: observed),
          '$minute:00');
    }
  });

  test(
      'breaks and shootout display status instead of the previous period timer',
      () {
    for (final (state, english, korean) in [
      (3, 'Half Time', '하프타임'),
      (4, 'Waiting for extra time', '연장전 준비'),
      (9, 'Penalty-shootout', '승부차기'),
      (11, 'Suspended', '경기 중단'),
      (18, 'Interrupted', '일시 중단'),
      (21, 'Pause extra time', '연장 후반 준비'),
      (25, 'Waiting for penalties', '승부차기 준비'),
    ]) {
      final fixture = _fixture(state);
      expect(fixtureHasPlayingClock(fixture), isFalse);
      expect(matchStatusLabel(fixture, locale: en, clock: _clock(observed)),
          english);
      expect(matchStatusLabel(fixture, locale: ko, clock: _clock(observed)),
          korean);
    }
  });

  test('caps at server freshness limit and does not add server age twice', () {
    final sample = _clock(observed, minute: 65, second: 31, age: 40);
    expect(sample.totalSecondsAt(observed), 65 * 60 + 31);
    expect(sample.totalSecondsAt(observed.add(const Duration(seconds: 30))),
        65 * 60 + 36);
    expect(
        sample.isRunningAt(observed.add(const Duration(seconds: 5))), isFalse);
    for (final sample in [
      _clock(observed, ticking: false),
      _clock(observed, stale: true),
    ]) {
      expect(sample.totalSecondsAt(observed.add(const Duration(minutes: 5))),
          sample.minutes! * 60);
    }
    expect(matchStatusLabel(_fixture(22), locale: en), 'Live');
    expect(
        matchStatusLabel(_fixture(22),
            locale: ko, clock: _clock(observed, second: null)),
        '라이브');
  });

  test('upcoming date and time match each language and retain local time',
      () async {
    await initializeDateFormatting('ko');
    final kickoff = DateTime(2026, 10, 11, 1, 30);
    expect(matchKickoffLabels(kickoff, locale: en),
        (date: 'Sun, Oct 11', time: '1:30 AM'));
    expect(matchKickoffLabels(kickoff, locale: ko),
        (date: '10월 11일 (일)', time: '1:30 AM'));
    expect(matchKickoffLabels(kickoff.toUtc(), locale: ko),
        matchKickoffLabels(kickoff, locale: ko));
    expect(
        matchKickoffLabels(null, locale: ko), (date: '날짜 미정', time: '시간 미정'));
  });

  testWidgets(
      'ticks every second, resyncs and stops for halftime and full time',
      (tester) async {
    await withClock(Clock(() => tester.binding.clock.now()), () async {
      Future<void> show(Fixture fixture, FixtureClock sample,
          {Locale locale = en}) async {
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: MatchStatusLabel(fixture: fixture, clock: sample),
        ));
        await tester.pump();
      }

      final sample = _clock(clock.now(), minute: 65, second: 31);
      await show(_fixture(22), sample);
      expect(find.text('65:31'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('65:32'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('65:33'), findsOneWidget);

      await show(_fixture(22), _clock(clock.now(), minute: 66, second: 5));
      expect(find.text('66:05'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('66:06'), findsOneWidget);

      await show(_fixture(3), sample);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Half Time'), findsOneWidget);

      await show(_fixture(22), _clock(clock.now(), minute: 63, second: 59),
          locale: ko);
      expect(find.text("후반 18'"), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text("후반 19'"), findsOneWidget);

      await show(_fixture(5, status: FixtureStatus.past), sample, locale: ko);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('경기 종료'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('freezes stale clocks and can resume from a new server sample',
      (tester) async {
    await withClock(Clock(() => tester.binding.clock.now()), () async {
      Future<void> show(FixtureClock sample) => tester.pumpWidget(MaterialApp(
            home: MatchStatusLabel(fixture: _fixture(22), clock: sample),
          ));
      await show(_clock(clock.now(), minute: 65, second: 31, age: 43));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('65:33'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('65:33'), findsOneWidget);
      await show(_clock(clock.now(), minute: 65, second: 50));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('65:51'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });
}

Fixture _fixture(int state,
        {FixtureStatus status = FixtureStatus.live, String? name}) =>
    Fixture(
      fixtureId: 1,
      seasonId: 1,
      competitionId: 2,
      homeTeamId: 83,
      awayTeamId: 86,
      competitionType: CompetitionType.europe,
      roundName: 'Final',
      status: status,
      stateId: state,
      stateName: name,
      startingAt: '2026-09-24T19:00:00Z',
    );

FixtureClock _clock(
  DateTime receivedAt, {
  int minute = 63,
  int? second = 0,
  int from = 45,
  int period = 2,
  bool ticking = true,
  bool stale = false,
  double age = 0,
}) =>
    FixtureClock(
      periodTypeId: period,
      countsFrom: from,
      minutes: minute,
      seconds: second,
      ticking: ticking,
      isStale: stale,
      sampleAgeSeconds: age,
      receivedAt: receivedAt,
    );
