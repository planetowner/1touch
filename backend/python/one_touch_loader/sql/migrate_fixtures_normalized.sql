-- fixtures는 아직 다시 적재하기 전의 빈 테이블만 교체해요. 기존 경기 행이 있으면
-- 실행 스크립트가 백업 전에 중단해 데이터 변환을 추측하지 않아요.
ALTER TABLE fixture_team_stats_raw
  DROP FOREIGN KEY fk_ftsr_fixture;

DROP TABLE fixtures;

CREATE TABLE rounds (
  round_id INT NOT NULL,
  stage_id INT NOT NULL,
  name VARCHAR(128) NOT NULL,

  PRIMARY KEY (round_id),
  KEY idx_rounds_stage (stage_id),

  CONSTRAINT fk_rounds_stage
    FOREIGN KEY (stage_id) REFERENCES stages(stage_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE venues (
  venue_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,

  PRIMARY KEY (venue_id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_states (
  state_id INT UNSIGNED NOT NULL,
  state_code VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,

  PRIMARY KEY (state_id),
  UNIQUE KEY uq_fixture_states_code (state_code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

-- Sportmonks aggregate 원본을 쓰고 팀·라운드 조합으로 대진을 추정하지 않아요.
DROP TABLE knockout_ties;

CREATE TABLE aggregates (
  aggregate_id BIGINT UNSIGNED NOT NULL COMMENT 'Sportmonks aggregate.id',
  stage_id INT NOT NULL,
  winner_team_id BIGINT UNSIGNED NULL COMMENT 'Sportmonks winner_participant_id',

  PRIMARY KEY (aggregate_id),
  KEY idx_aggregates_stage (stage_id),
  KEY idx_aggregates_winner_team (winner_team_id),

  CONSTRAINT fk_aggregates_stage
    FOREIGN KEY (stage_id) REFERENCES stages(stage_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_aggregates_winner_team
    FOREIGN KEY (winner_team_id) REFERENCES teams(team_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixtures (
  fixture_id BIGINT UNSIGNED NOT NULL COMMENT 'Sportmonks v3 id',
  stage_id INT NOT NULL,
  round_id INT NULL,
  group_id INT NULL,
  aggregate_id BIGINT UNSIGNED NULL COMMENT 'Sportmonks aggregate_id',
  leg VARCHAR(10) NOT NULL COMMENT 'Sportmonks leg 원문',
  home_team_id BIGINT UNSIGNED NOT NULL,
  away_team_id BIGINT UNSIGNED NOT NULL,
  starting_at DATETIME NULL,
  venue_id BIGINT UNSIGNED NULL,
  state_id INT UNSIGNED NOT NULL,
  home_score SMALLINT UNSIGNED NULL,
  away_score SMALLINT UNSIGNED NULL,
  home_penalty_score SMALLINT UNSIGNED NULL,
  away_penalty_score SMALLINT UNSIGNED NULL,

  PRIMARY KEY (fixture_id),
  KEY idx_fixtures_stage_starting_at (stage_id, starting_at),
  KEY idx_fixtures_round (round_id),
  KEY idx_fixtures_group (group_id),
  KEY idx_fixtures_aggregate (aggregate_id),
  KEY idx_fixtures_home_starting_at (home_team_id, starting_at),
  KEY idx_fixtures_away_starting_at (away_team_id, starting_at),
  KEY idx_fixtures_state_starting_at (state_id, starting_at),
  KEY idx_fixtures_venue (venue_id),

  CONSTRAINT fk_fixtures_stage
    FOREIGN KEY (stage_id) REFERENCES stages(stage_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_fixtures_round
    FOREIGN KEY (round_id) REFERENCES rounds(round_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_fixtures_group
    FOREIGN KEY (group_id) REFERENCES stage_groups(group_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_fixtures_aggregate
    FOREIGN KEY (aggregate_id) REFERENCES aggregates(aggregate_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_fixtures_home_team
    FOREIGN KEY (home_team_id) REFERENCES teams(team_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_fixtures_away_team
    FOREIGN KEY (away_team_id) REFERENCES teams(team_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_fixtures_venue
    FOREIGN KEY (venue_id) REFERENCES venues(venue_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_fixtures_state
    FOREIGN KEY (state_id) REFERENCES fixture_states(state_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE fixture_team_stats_raw
  ADD CONSTRAINT fk_ftsr_fixture
    FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id)
    ON UPDATE CASCADE ON DELETE CASCADE;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'fixtures'
ORDER BY ordinal_position;

SELECT
  information_schema.tables.table_name,
  MAX(counts.row_count) AS row_count
FROM information_schema.tables
LEFT JOIN (
  SELECT 'aggregates' AS counted_table, COUNT(*) AS row_count FROM aggregates
  UNION ALL
  SELECT 'fixtures', COUNT(*) FROM fixtures
  UNION ALL
  SELECT 'rounds', COUNT(*) FROM rounds
  UNION ALL
  SELECT 'venues', COUNT(*) FROM venues
  UNION ALL
  SELECT 'fixture_states', COUNT(*) FROM fixture_states
) AS counts
  ON counts.counted_table = information_schema.tables.table_name
WHERE table_schema = DATABASE()
  AND table_name IN ('aggregates', 'fixtures', 'rounds', 'venues', 'fixture_states')
GROUP BY information_schema.tables.table_name
ORDER BY information_schema.tables.table_name;

SELECT
  constraint_name,
  table_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND referenced_table_name IS NOT NULL
  AND (
    table_name = 'fixtures'
    OR table_name = 'aggregates'
    OR constraint_name = 'fk_ftsr_fixture'
  )
ORDER BY table_name, constraint_name;
