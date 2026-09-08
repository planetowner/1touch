-- leg_number는 Sportmonks의 1/1, 1/2, 2/2 원문을 보존하지 않아요.
-- 정확한 leg와 aggregate를 다시 적재하기 위해 기존 경기 파생 데이터도 함께 비워요.
DELETE FROM fixture_formations;
DELETE FROM fixture_lineups;
DELETE FROM fixture_team_stats_raw;
DELETE FROM fixtures;

-- knockout_ties는 팀과 라운드를 조합해 대진을 추정했어요. Sportmonks가 제공한
-- aggregate만 원본으로 저장하기 위해 이 테이블을 교체해요.
DROP TABLE knockout_ties;

CREATE TABLE aggregates (
  aggregate_id  BIGINT UNSIGNED NOT NULL COMMENT 'Sportmonks aggregate.id',
  stage_id      INT NOT NULL,
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

ALTER TABLE fixtures
  DROP CHECK chk_fixtures_leg_number,
  ADD COLUMN aggregate_id BIGINT UNSIGNED NULL COMMENT 'Sportmonks aggregate_id' AFTER group_id,
  CHANGE COLUMN leg_number leg VARCHAR(10) NOT NULL COMMENT 'Sportmonks leg 원문' AFTER aggregate_id,
  ADD KEY idx_fixtures_aggregate (aggregate_id),
  ADD CONSTRAINT fk_fixtures_aggregate
    FOREIGN KEY (aggregate_id) REFERENCES aggregates(aggregate_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

SELECT column_name, column_type, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'fixtures'
ORDER BY ordinal_position;

SELECT column_name, column_type, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'aggregates'
ORDER BY ordinal_position;

SELECT
  constraint_name,
  table_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND (
    table_name = 'aggregates'
    OR constraint_name = 'fk_fixtures_aggregate'
  )
  AND referenced_table_name IS NOT NULL
ORDER BY table_name, constraint_name;
