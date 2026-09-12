-- teams.team_id는 Sportmonks 팀 ID를 1Touch의 대표 팀 ID로 써요.
-- Capology 팀 페이지의 slug처럼 다른 공급자의 조회 키는 이 테이블에 저장해요.
CREATE TABLE team_external_ids (
  team_id          BIGINT UNSIGNED NOT NULL,
  provider         VARCHAR(50) NOT NULL,
  external_team_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,

  PRIMARY KEY (provider, external_team_id),
  UNIQUE KEY uq_team_external_provider (team_id, provider),

  CONSTRAINT fk_team_external_ids_team
    FOREIGN KEY (team_id) REFERENCES teams(team_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'team_external_ids'
ORDER BY ordinal_position;

SELECT
  constraint_name,
  table_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND constraint_name = 'fk_team_external_ids_team';
