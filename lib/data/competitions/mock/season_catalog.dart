import 'package:onetouch/models/season.dart';

// SEASONS  (seasons table)  — 2025/26 current season per league
// ═══════════════════════════════════════════════════════════

const mockSeasons = <Season>[
  Season(
      seasonId: 25583,
      leagueId: 8,
      name: '2025/2026',
      isCurrent: true,
      startingAt: '2025-08-15 00:00:00',
      endingAt: '2026-05-24 00:00:00'),
  Season(
      seasonId: 25659,
      leagueId: 564,
      name: '2025/2026',
      isCurrent: true,
      startingAt: '2025-08-15 00:00:00',
      endingAt: '2026-05-24 00:00:00'),
  Season(
      seasonId: 25533,
      leagueId: 384,
      name: '2025/2026',
      isCurrent: true,
      startingAt: '2025-08-23 00:00:00',
      endingAt: '2026-05-24 00:00:00'),
  Season(
      seasonId: 25646,
      leagueId: 82,
      name: '2025/2026',
      isCurrent: true,
      startingAt: '2025-08-22 00:00:00',
      endingAt: '2026-05-16 00:00:00'),
  Season(
      seasonId: 25651,
      leagueId: 301,
      name: '2025/2026',
      isCurrent: true,
      startingAt: '2025-08-15 00:00:00',
      endingAt: '2026-05-23 00:00:00'),
  // ── UCL / Europa ──────────────────────────────────────────
  Season(
      seasonId: 23804,
      leagueId: 2,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-09-16 00:00:00',
      endingAt: '2026-05-30 00:00:00'),
  Season(
      seasonId: 23805,
      leagueId: 5,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-09-24 00:00:00',
      endingAt: '2026-05-20 00:00:00'),
  // ── Domestic cups ─────────────────────────────────────────
  Season(
      seasonId: 23900,
      leagueId: 24,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-11-01 00:00:00',
      endingAt: '2026-05-16 00:00:00'),
  Season(
      seasonId: 23901,
      leagueId: 27,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-08-12 00:00:00',
      endingAt: '2026-03-15 00:00:00'),
  Season(
      seasonId: 23902,
      leagueId: 570,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-10-28 00:00:00',
      endingAt: '2026-04-25 00:00:00'),
  Season(
      seasonId: 23903,
      leagueId: 390,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-09-23 00:00:00',
      endingAt: '2026-05-13 00:00:00'),
  Season(
      seasonId: 23904,
      leagueId: 392,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-08-15 00:00:00',
      endingAt: '2026-05-23 00:00:00'),
  Season(
      seasonId: 23905,
      leagueId: 569,
      name: '2025/26',
      isCurrent: true,
      startingAt: '2025-10-18 00:00:00',
      endingAt: '2026-05-23 00:00:00'),
];

Season mockCurrentSeason(int leagueId) =>
    mockSeasons.firstWhere((s) => s.leagueId == leagueId && s.isCurrent);

// ═══════════════════════════════════════════════════════════
