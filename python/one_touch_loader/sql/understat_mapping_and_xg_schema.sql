-- understat_mapping_and_xg_schema.sql
-- Purpose:
--   1) Create Understat -> Sportmonks mapping tables.
--   2) Replace the old FBref-style xg_standings table with the new Understat-based design.
--

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. Understat league -> Sportmonks league mapping
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS understat_league_map (
  sportmonks_league_id BIGINT UNSIGNED NOT NULL,
  understat_league_key VARCHAR(80) NOT NULL,
  understat_league_id INT UNSIGNED DEFAULT NULL,
  understat_url VARCHAR(255) DEFAULT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (sportmonks_league_id),
  UNIQUE KEY uq_understat_league_key (understat_league_key),

  CONSTRAINT fk_understat_league_map_league
    FOREIGN KEY (sportmonks_league_id) REFERENCES leagues(league_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Maps soccerdata/Understat league keys to Sportmonks league IDs.';

-- Big 5 league mapping used by the current standings loader.
-- understat_league_id/url can be filled later from soccerdata.Understat.read_leagues().
INSERT INTO understat_league_map (
  sportmonks_league_id,
  understat_league_key,
  understat_league_id,
  understat_url,
  is_active
) VALUES
  (8,   'ENG-Premier League', NULL, NULL, 1),
  (82,  'GER-Bundesliga',     NULL, NULL, 1),
  (301, 'FRA-Ligue 1',        NULL, NULL, 1),
  (384, 'ITA-Serie A',        NULL, NULL, 1),
  (564, 'ESP-La Liga',        NULL, NULL, 1)
ON DUPLICATE KEY UPDATE
  understat_league_key = VALUES(understat_league_key),
  understat_league_id = VALUES(understat_league_id),
  understat_url = VALUES(understat_url),
  is_active = VALUES(is_active);

-- -----------------------------------------------------------------------------
-- 2. Understat season -> Sportmonks season mapping
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS understat_season_map (
  sportmonks_season_id BIGINT UNSIGNED NOT NULL,
  sportmonks_league_id BIGINT UNSIGNED NOT NULL,
  understat_league_key VARCHAR(80) NOT NULL,
  understat_season_id INT UNSIGNED NOT NULL COMMENT 'Understat season start year, e.g. 2025 for 2025/2026.',
  understat_season_label VARCHAR(10) DEFAULT NULL COMMENT 'soccerdata display label, e.g. 2526.',
  season_start_year SMALLINT UNSIGNED NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (sportmonks_season_id),
  UNIQUE KEY uq_understat_season (understat_league_key, understat_season_id),
  KEY idx_understat_season_map_league (sportmonks_league_id, sportmonks_season_id),

  CONSTRAINT fk_understat_season_map_season
    FOREIGN KEY (sportmonks_season_id) REFERENCES seasons(season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_understat_season_map_league
    FOREIGN KEY (sportmonks_league_id) REFERENCES leagues(league_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_understat_season_map_understat_league
    FOREIGN KEY (understat_league_key) REFERENCES understat_league_map(understat_league_key)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Maps Sportmonks season IDs to Understat season start years.';

-- Auto-create season mappings from Sportmonks season starting_at.
-- Example: Sportmonks 2025/2026 starting_at=2025-08-xx -> Understat season_id=2025, label=2526.
INSERT INTO understat_season_map (
  sportmonks_season_id,
  sportmonks_league_id,
  understat_league_key,
  understat_season_id,
  understat_season_label,
  season_start_year,
  is_active
)
SELECT
  s.season_id,
  s.league_id,
  ulm.understat_league_key,
  YEAR(s.starting_at) AS understat_season_id,
  CONCAT(
    LPAD(MOD(YEAR(s.starting_at), 100), 2, '0'),
    LPAD(MOD(YEAR(s.starting_at) + 1, 100), 2, '0')
  ) AS understat_season_label,
  YEAR(s.starting_at) AS season_start_year,
  1 AS is_active
FROM seasons s
JOIN understat_league_map ulm
  ON ulm.sportmonks_league_id = s.league_id
WHERE s.starting_at IS NOT NULL
  AND ulm.is_active = 1
ON DUPLICATE KEY UPDATE
  sportmonks_league_id = VALUES(sportmonks_league_id),
  understat_league_key = VALUES(understat_league_key),
  understat_season_id = VALUES(understat_season_id),
  understat_season_label = VALUES(understat_season_label),
  season_start_year = VALUES(season_start_year),
  is_active = VALUES(is_active);

-- -----------------------------------------------------------------------------
-- 3. Understat team -> Sportmonks team mapping
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS understat_team_map (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

  sportmonks_team_id BIGINT UNSIGNED NOT NULL,
  sportmonks_league_id BIGINT UNSIGNED NOT NULL,
  sportmonks_season_id BIGINT UNSIGNED NOT NULL,

  understat_league_key VARCHAR(80) NOT NULL,
  understat_season_id INT UNSIGNED NOT NULL,
  understat_team_id INT UNSIGNED NOT NULL,
  understat_team_name VARCHAR(160) NOT NULL,
  understat_team_code VARCHAR(16) DEFAULT NULL,

  match_status ENUM('manual','auto_exact','auto_fuzzy','needs_review') NOT NULL DEFAULT 'needs_review',
  confidence DECIMAL(5,4) DEFAULT NULL,
  notes VARCHAR(255) DEFAULT NULL,

  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),

  UNIQUE KEY uq_understat_team_scope (
    understat_league_key,
    understat_season_id,
    understat_team_id
  ),

  UNIQUE KEY uq_sportmonks_team_scope (
    sportmonks_league_id,
    sportmonks_season_id,
    sportmonks_team_id
  ),

  KEY idx_understat_team_map_sm_season (sportmonks_league_id, sportmonks_season_id),
  KEY idx_understat_team_map_sm_team (sportmonks_team_id),
  KEY idx_understat_team_map_status (match_status),

  CONSTRAINT fk_understat_team_map_team
    FOREIGN KEY (sportmonks_team_id) REFERENCES teams(team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_understat_team_map_league
    FOREIGN KEY (sportmonks_league_id) REFERENCES leagues(league_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_understat_team_map_season
    FOREIGN KEY (sportmonks_season_id) REFERENCES seasons(season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_understat_team_map_understat_league
    FOREIGN KEY (understat_league_key) REFERENCES understat_league_map(understat_league_key)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_understat_team_map_understat_season
    FOREIGN KEY (understat_league_key, understat_season_id)
    REFERENCES understat_season_map(understat_league_key, understat_season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Maps Understat team IDs/names to Sportmonks team IDs per league-season.';

-- -----------------------------------------------------------------------------
-- 4. Replace old xg_standings with the new Understat-based xG table
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS xg_standings;

CREATE TABLE xg_standings (
  league_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,

  position SMALLINT UNSIGNED NOT NULL,
  matches_played SMALLINT UNSIGNED NOT NULL,

  -- These are NOT real-goal W/D/L.
  -- They are xG-result W/D/L using 1touch's rule:
  -- if team_xg > opponent_xg => W, equal => D, lower => L.
  won SMALLINT UNSIGNED NOT NULL,
  draw SMALLINT UNSIGNED NOT NULL,
  lost SMALLINT UNSIGNED NOT NULL,

  xg DECIMAL(9,3) NOT NULL,
  xga DECIMAL(9,3) NOT NULL,

  -- This is NOT Understat's expected_points field.
  -- It is calculated by 1touch from xG-result W/D/L:
  -- xPts = won * 3 + draw * 1.
  xpts DECIMAL(7,2) NOT NULL,

  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (league_id, season_id, team_id),
  KEY idx_xg_standings_rank (league_id, season_id, position),
  KEY idx_xg_standings_xpts (league_id, season_id, xpts DESC),
  KEY idx_xg_standings_team (team_id),

  CONSTRAINT fk_xg_standings_league
    FOREIGN KEY (league_id) REFERENCES leagues(league_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_xg_standings_season
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_xg_standings_team
    FOREIGN KEY (team_id) REFERENCES teams(team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT chk_xg_standings_record
    CHECK (matches_played = won + draw + lost)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Understat-based xG table. W/D/L and xPts are calculated from xG-result, not real goals.';

COMMIT;

-- -----------------------------------------------------------------------------
-- Verification queries
-- -----------------------------------------------------------------------------
SELECT * FROM understat_league_map ORDER BY sportmonks_league_id;

SELECT
  sportmonks_league_id,
  sportmonks_season_id,
  understat_league_key,
  understat_season_id,
  understat_season_label,
  is_active
FROM understat_season_map
ORDER BY sportmonks_league_id, season_start_year DESC;

SHOW CREATE TABLE understat_team_map;
SHOW CREATE TABLE xg_standings;
