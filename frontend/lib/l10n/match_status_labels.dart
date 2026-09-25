import 'package:flutter/widgets.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_clock.dart';

bool fixtureHasPlayingClock(Fixture fixture) =>
    fixture.status == FixtureStatus.live &&
    (fixture.stateId == null || const {2, 6, 22, 23}.contains(fixture.stateId));

String matchStatusLabel(
  Fixture fixture, {
  required Locale locale,
  FixtureClock? clock,
  DateTime? now,
}) {
  final language = locale.languageCode;
  // 일본어·중국어는 기존 표시를 유지해요.
  if (language != 'en' && language != 'ko') {
    return translateMessage(
        locale, fixture.status == FixtureStatus.live ? 'Live' : 'Final');
  }
  final korean = language == 'ko';
  final stateId = fixture.stateId;
  // 라운드의 Final(결승)과 종료 상태의 문구를 분리해요.
  if (const {5, 7, 8}.contains(stateId) ||
      (stateId == null && fixture.status == FixtureStatus.past)) {
    return korean ? '경기 종료' : 'Full Time';
  }

  if (fixtureHasPlayingClock(fixture) && clock != null) {
    final total = clock.totalSecondsAt(now ?? DateTime.now());
    if (total != null) {
      if (!korean) {
        return '${(total ~/ 60).toString().padLeft(2, '0')}:'
            '${(total % 60).toString().padLeft(2, '0')}';
      }
      final period = switch (stateId) {
        2 => ('전반', clock.countsFrom),
        22 => ('후반', clock.countsFrom),
        6 => ('연장 전반', 90),
        // periods의 연장은 하나로 합쳐져 있어도 실제 경기 상태로 후반을 구분해요.
        23 => ('연장 후반', 105),
        _ => switch (clock.periodTypeId) {
            1 => ('전반', clock.countsFrom),
            2 => ('후반', clock.countsFrom),
            _ => (null, null),
          },
      };
      if (period.$1 != null && period.$2 != null) {
        final minute = total ~/ 60 - period.$2!;
        if (minute >= 0) return "${period.$1} $minute'";
      }
    }
  }

  final paused = switch (stateId) {
    3 => ('Half Time', '하프타임'),
    4 => ('Waiting for extra time', '연장전 준비'),
    9 => ('Penalty-shootout', '승부차기'),
    11 => ('Suspended', '경기 중단'),
    18 => ('Interrupted', '일시 중단'),
    21 => ('Pause extra time', '연장 후반 준비'),
    25 => ('Waiting for penalties', '승부차기 준비'),
    _ => null,
  };
  if (paused != null) return korean ? paused.$2 : paused.$1;

  // 시계가 없으면 킥오프 시각으로 경기 시간을 추측하지 않아요.
  if (fixture.status == FixtureStatus.live) return korean ? '라이브' : 'Live';
  return fixture.stateName ?? '—';
}
