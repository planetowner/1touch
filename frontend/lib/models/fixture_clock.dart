class FixtureClock {
  const FixtureClock({
    required this.periodTypeId,
    required this.countsFrom,
    required this.minutes,
    required this.seconds,
    required this.ticking,
    required this.isStale,
    required this.sampleAgeSeconds,
    required this.receivedAt,
  });

  final int? periodTypeId;
  final int? countsFrom;
  final int? minutes;
  final int? seconds;
  final bool ticking;
  final bool isStale;
  final double sampleAgeSeconds;
  final DateTime receivedAt;

  // 서버 fixture_clock_repo와 동일하게 관측 후 45초까지만 시계를 진행해요.
  static const maxAgeSeconds = 45;

  bool isRunningAt(DateTime now) =>
      ticking &&
      !isStale &&
      minutes != null &&
      seconds != null &&
      sampleAgeSeconds + now.difference(receivedAt).inMilliseconds / 1000 <
          maxAgeSeconds;

  int? totalSecondsAt(DateTime now) {
    if (minutes == null || seconds == null) return null;
    final base = minutes! * 60 + seconds!;
    if (!ticking || isStale) return base;
    // API의 분·초에는 수집 이후 경과 시간이 이미 반영돼 있어요.
    final elapsed = now.difference(receivedAt).inMilliseconds / 1000;
    final remaining =
        (maxAgeSeconds - sampleAgeSeconds).clamp(0, maxAgeSeconds);
    return base + elapsed.clamp(0, remaining).floor();
  }
}
