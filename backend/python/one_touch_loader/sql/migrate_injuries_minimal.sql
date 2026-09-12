-- 기존 15컬럼·0행을 사전 검증하고 백업한 뒤 실행해요.
-- 새 사전은 create_team_player_injuries.sql에서 만들고 기존 테이블만 아래에서 바꿔요.
ALTER TABLE team_player_injuries
  DROP INDEX idx_tpi_team_active,
  DROP INDEX idx_tpi_player_active,
  DROP INDEX idx_tpi_team_completed,
  DROP INDEX idx_tpi_last_seen,
  DROP COLUMN category,
  DROP COLUMN type_name,
  DROP COLUMN player_name,
  DROP COLUMN games_missed,
  DROP COLUMN completed,
  DROP COLUMN is_active,
  DROP COLUMN last_seen_at,
  DROP COLUMN created_at,
  DROP COLUMN updated_at,
  MODIFY sideline_id BIGINT UNSIGNED NOT NULL,
  MODIFY team_id BIGINT UNSIGNED NOT NULL,
  MODIFY player_id BIGINT UNSIGNED NOT NULL,
  MODIFY type_id BIGINT UNSIGNED NOT NULL,
  ADD KEY idx_tpi_player (player_id),
  ADD KEY idx_tpi_type (type_id),
  ADD CONSTRAINT fk_tpi_team FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT fk_tpi_player FOREIGN KEY (player_id) REFERENCES players (player_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT fk_tpi_type FOREIGN KEY (type_id) REFERENCES injury_types (type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE;
