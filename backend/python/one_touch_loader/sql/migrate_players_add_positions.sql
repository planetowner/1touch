-- Sportmonks의 선수 원본 필드 이름은 detailed_position_id예요.
-- 1Touch에서는 players.position_id가 positions.position_id를 참조해요.
-- position_group_id는 Sportmonks position_id, 즉 기본 포지션 그룹이에요.
CREATE TABLE positions (
  position_id         INT UNSIGNED NOT NULL,
  position_code       VARCHAR(10) NOT NULL,
  position_group_id   INT UNSIGNED NOT NULL,
  position_group_code VARCHAR(10) NOT NULL,

  PRIMARY KEY (position_id),
  UNIQUE KEY uq_positions_code (position_code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO positions (
  position_id,
  position_code,
  position_group_id,
  position_group_code
) VALUES
  (24,  'GK', 24, 'GK'),
  (148, 'CB', 25, 'DF'),
  (149, 'DM', 26, 'MF'),
  (150, 'AM', 26, 'MF'),
  (151, 'ST', 27, 'FW'),
  (152, 'LW', 27, 'FW'),
  (153, 'CM', 26, 'MF'),
  (154, 'RB', 25, 'DF'),
  (155, 'LB', 25, 'DF'),
  (156, 'RW', 27, 'FW'),
  (157, 'LM', 26, 'MF'),
  (158, 'RM', 26, 'MF'),
  (163, 'SS', 27, 'FW');

ALTER TABLE players
  ADD COLUMN position_id INT UNSIGNED NULL AFTER player_id,
  ADD KEY idx_players_position (position_id),
  ADD CONSTRAINT fk_players_position
    FOREIGN KEY (position_id) REFERENCES positions(position_id)
    ON UPDATE CASCADE ON DELETE RESTRICT;

SELECT
  position_id,
  position_code,
  position_group_id,
  position_group_code
FROM positions
ORDER BY position_id;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'players'
  AND column_name = 'position_id';

SELECT
  constraint_name,
  table_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND constraint_name = 'fk_players_position';
