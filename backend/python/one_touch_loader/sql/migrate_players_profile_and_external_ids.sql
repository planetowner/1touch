-- 현재 players.player_id는 Sportmonks 선수 ID를 1Touch의 대표 선수 ID로 써요.
-- 다른 공급자 ID는 player_external_ids에 저장해요.
ALTER TABLE players
  CHANGE COLUMN name full_name VARCHAR(255) NOT NULL,
  DROP COLUMN firstname,
  DROP COLUMN lastname,
  ADD COLUMN nationality_id BIGINT UNSIGNED NULL,
  ADD COLUMN date_of_birth DATE NULL,
  ADD COLUMN height_cm SMALLINT UNSIGNED NULL,
  ADD COLUMN weight_kg SMALLINT UNSIGNED NULL,
  ADD COLUMN image_path VARCHAR(512) NULL;

ALTER TABLE players
  MODIFY COLUMN display_name VARCHAR(255) NOT NULL AFTER player_id,
  MODIFY COLUMN full_name VARCHAR(255) NOT NULL AFTER display_name,
  MODIFY COLUMN position_id INT UNSIGNED NOT NULL AFTER full_name,
  MODIFY COLUMN nationality_id BIGINT UNSIGNED NULL AFTER position_id,
  MODIFY COLUMN date_of_birth DATE NULL AFTER nationality_id,
  MODIFY COLUMN height_cm SMALLINT UNSIGNED NULL AFTER date_of_birth,
  MODIFY COLUMN weight_kg SMALLINT UNSIGNED NULL AFTER height_cm,
  MODIFY COLUMN image_path VARCHAR(512) NULL AFTER weight_kg;

CREATE TABLE player_external_ids (
  player_id          BIGINT UNSIGNED NOT NULL,
  provider           VARCHAR(50) NOT NULL,
  external_player_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,

  PRIMARY KEY (provider, external_player_id),
  UNIQUE KEY uq_player_external_provider (player_id, provider),

  CONSTRAINT fk_player_external_ids_player
    FOREIGN KEY (player_id) REFERENCES players(player_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

-- 현재 players.player_id는 모두 Sportmonks에서 직접 적재해 정확히 연결돼요.
-- player_wage_estimates의 Capology ID는 복사하지 마세요. 그 이전 행은 지금은 없앤
-- 이름 기반 추정으로 연결됐어요.
INSERT INTO player_external_ids (player_id, provider, external_player_id)
SELECT player_id, 'sportmonks', CAST(player_id AS CHAR)
FROM players;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'players'
ORDER BY ordinal_position;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'player_external_ids'
ORDER BY ordinal_position;

SELECT provider, COUNT(*) AS mapped_players
FROM player_external_ids
GROUP BY provider
ORDER BY provider;

SELECT
  constraint_name,
  table_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND constraint_name IN (
    'fk_players_position',
    'fk_player_external_ids_player'
  )
ORDER BY table_name, constraint_name;
