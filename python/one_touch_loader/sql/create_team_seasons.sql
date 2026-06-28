-- team_seasons: which teams belong to which (Big5 domestic league) season.
--
-- Populated from the Sportmonks teams/seasons/{season_id} endpoint during the
-- Big5 bootstrap (upsert_teams_for_season). Lets the API resolve a team's
-- current-season domestic league context even before that season's fixtures
-- exist (e.g. at season rollover / right after promotion-relegation), instead
-- of inferring the league from the most recent fixture.
--
-- Only Big5 domestic-league seasons are recorded here, so league_id is always
-- the team's domestic league.

CREATE TABLE IF NOT EXISTS team_seasons (
  team_id    BIGINT UNSIGNED NOT NULL,
  season_id  BIGINT UNSIGNED NOT NULL,
  league_id  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (team_id, season_id),
  KEY idx_ts_season (season_id),
  KEY idx_ts_league_season (league_id, season_id)
);

-- One-time backfill from existing domestic-league fixtures, so the table is
-- usable immediately without re-running the full bootstrap. Idempotent
-- (ON DUPLICATE KEY UPDATE); the bootstrap loader keeps it fresh afterwards
-- and additionally covers the pre-fixture rollover gap via teams/seasons.
INSERT INTO team_seasons (team_id, season_id, league_id)
SELECT DISTINCT team_id, season_id, league_id
FROM (
  SELECT f.home_team_id AS team_id, f.season_id, f.league_id
  FROM fixtures f
  WHERE f.competition_type = 'league'
    AND f.league_id IN (8, 82, 301, 384, 564)
  UNION
  SELECT f.away_team_id AS team_id, f.season_id, f.league_id
  FROM fixtures f
  WHERE f.competition_type = 'league'
    AND f.league_id IN (8, 82, 301, 384, 564)
) t
WHERE team_id IS NOT NULL
ON DUPLICATE KEY UPDATE league_id = VALUES(league_id);
