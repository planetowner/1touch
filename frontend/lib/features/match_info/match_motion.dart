import 'package:flutter/animation.dart';

const matchMotionCurve = Cubic(0.7, 0, 0.3, 1);
const matchMotionDurationMs = 833;
const matchArrowStaggerMs = 420;
const matchShotCircleDurationMs = 420;
const matchShotLineDelayMs = 83;
const matchShotStaggerMs = matchShotLineDelayMs;
const matchShotTimelineMs = matchShotCircleDurationMs + matchShotLineDelayMs;
const matchProgressionTimelineMs =
    matchMotionDurationMs + 2 * matchArrowStaggerMs;

int matchShotTimelineDurationMs(int shotCount) =>
    matchShotTimelineMs +
    (shotCount > 0 ? shotCount - 1 : 0) * matchShotStaggerMs;

double matchMotionSegmentProgress(
  double timeline, {
  required int totalMs,
  required int startMs,
  required int durationMs,
}) =>
    matchMotionCurve.transform(
      ((timeline * totalMs - startMs) / durationMs).clamp(0.0, 1.0),
    );
