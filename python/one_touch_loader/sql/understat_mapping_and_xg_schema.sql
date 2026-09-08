-- understat_mapping_and_xg_schema.sql
-- 하는 일:
--   1) Understat → Sportmonks 매핑 테이블을 만들어요.
--   2) 기존 FBref 방식 xg_standings를 Understat 기반 구조로 바꿔요.
--

START TRANSACTION;

-- -----------------------------------------------------------------------------
-- 1. Understat 리그 → Sportmonks 리그 매핑
-- Sportmonks는 공급자 용어인 league_id를 유지해요. 1Touch는 같은 ID를
-- competitions.competition_id에 저장해요. 공급자별 매핑 열 이름은
-- sportmonks_league_id와 understat_league_key로 유지해요.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS understat_league_map (
  sportmonks_league_id BIGINT UNSIGNED NOT NULL,
  understat_league_key VARCHAR(80) NOT NULL,

  PRIMARY KEY (sportmonks_league_id),
  UNIQUE KEY uq_understat_league_key (understat_league_key),

  CONSTRAINT fk_understat_league_map_competition
    FOREIGN KEY (sportmonks_league_id) REFERENCES competitions(competition_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Maps soccerdata/Understat league keys to Sportmonks league IDs.';

-- 현재 순위 로더가 쓰는 Big 5 리그 매핑이에요.
INSERT INTO understat_league_map (
  sportmonks_league_id,
  understat_league_key
) VALUES
  (8,   'ENG-Premier League'),
  (82,  'GER-Bundesliga'),
  (301, 'FRA-Ligue 1'),
  (384, 'ITA-Serie A'),
  (564, 'ESP-La Liga')
ON DUPLICATE KEY UPDATE
  understat_league_key = VALUES(understat_league_key);

-- -----------------------------------------------------------------------------
-- 2. Understat 시즌 → Sportmonks 시즌 매핑
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS understat_season_map (
  sportmonks_season_id BIGINT UNSIGNED NOT NULL,
  understat_season_key VARCHAR(10) NOT NULL,

  PRIMARY KEY (sportmonks_season_id),
  KEY idx_understat_season_key (understat_season_key),

  CONSTRAINT fk_understat_season_map_season
    FOREIGN KEY (sportmonks_season_id) REFERENCES seasons(season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Maps Sportmonks season IDs to soccerdata/Understat season keys.';

-- DB에 저장된 Sportmonks 시즌 이름으로 시즌 매핑을 자동으로 만들어요.
-- 실제 적재값과 같은 형식이에요. 예: 2025/2026 → 25-26
INSERT INTO understat_season_map (
  sportmonks_season_id,
  understat_season_key
)
SELECT
  s.season_id,
  CONCAT(
    SUBSTRING(s.name, 3, 2),
    '-',
    SUBSTRING(s.name, 8, 2)
  ) AS understat_season_key
FROM seasons s
JOIN understat_league_map ulm
  ON ulm.sportmonks_league_id = s.competition_id
ON DUPLICATE KEY UPDATE
  understat_season_key = VALUES(understat_season_key);

-- -----------------------------------------------------------------------------
-- 3. Understat 팀 → Sportmonks 팀 매핑
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS understat_team_map (
  understat_team_id INT NOT NULL,
  sportmonks_team_id BIGINT UNSIGNED NOT NULL,
  understat_team_name VARCHAR(160) NOT NULL,

  PRIMARY KEY (understat_team_id),
  UNIQUE KEY uq_understat_team_map_sportmonks_team (sportmonks_team_id),

  CONSTRAINT fk_understat_team_map_team
    FOREIGN KEY (sportmonks_team_id) REFERENCES teams(team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Maps Understat team IDs/names to Sportmonks team IDs.';

-- -----------------------------------------------------------------------------
-- 4. 기존 xg_standings를 Understat 기반 xG 테이블로 바꿔요.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS xg_standings;

CREATE TABLE xg_standings (
  competition_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,

  position SMALLINT UNSIGNED NOT NULL,
  matches_played SMALLINT UNSIGNED NOT NULL,

-- 실제 득점으로 계산한 승·무·패가 아니에요.
-- 1Touch 규칙으로 계산한 xG 승·무·패예요.
-- team_xg가 opponent_xg보다 높으면 W, 같으면 D, 낮으면 L이에요.
  won SMALLINT UNSIGNED NOT NULL,
  draw SMALLINT UNSIGNED NOT NULL,
  lost SMALLINT UNSIGNED NOT NULL,

  xg DECIMAL(9,3) NOT NULL,
  xga DECIMAL(9,3) NOT NULL,

-- Understat의 expected_points 필드가 아니에요.
-- 1Touch가 xG 승·무·패로 계산해요.
-- xPts = won * 3 + draw * 1.
  xpts DECIMAL(7,2) NOT NULL,

  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (competition_id, season_id, team_id),
  KEY idx_xg_standings_rank (competition_id, season_id, position),
  KEY idx_xg_standings_xpts (competition_id, season_id, xpts DESC),
  KEY idx_xg_standings_team (team_id),

  CONSTRAINT fk_xg_standings_competition
    FOREIGN KEY (competition_id) REFERENCES competitions(competition_id)
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
-- 확인 쿼리
-- -----------------------------------------------------------------------------
SELECT * FROM understat_league_map ORDER BY sportmonks_league_id;

SELECT
  s.competition_id,
  usm.sportmonks_season_id,
  usm.understat_season_key
FROM understat_season_map usm
JOIN seasons s ON s.season_id = usm.sportmonks_season_id
ORDER BY s.competition_id, s.name DESC;

SHOW CREATE TABLE understat_team_map;
SHOW CREATE TABLE xg_standings;
