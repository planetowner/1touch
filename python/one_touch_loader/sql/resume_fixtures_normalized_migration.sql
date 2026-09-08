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

SELECT
  (SELECT COUNT(*) FROM fixtures) AS fixtures_count,
  (SELECT COUNT(*) FROM aggregates) AS aggregates_count,
  (SELECT COUNT(*) FROM rounds) AS rounds_count,
  (SELECT COUNT(*) FROM venues) AS venues_count,
  (SELECT COUNT(*) FROM fixture_states) AS fixture_states_count,
  (SELECT COUNT(*) FROM fixture_team_stats_raw) AS fixture_team_stats_raw_count;
