SET NAMES utf8mb4;

-- 확인된 기존 14·8컬럼의 빈 결과 테이블을 정리해요. 백업과 사전 검증이 포함된
-- run_best_eleven_minimal_migration.ps1로 실행한 뒤 새 선정 기준으로 다시 계산해요.
ALTER TABLE team_best_eleven_formations
  DROP CHECK chk_tbef_matches,
  DROP CHECK chk_tbef_default,
  DROP PRIMARY KEY,
  DROP COLUMN id,
  DROP COLUMN total_valid_matches,
  DROP COLUMN is_default,
  DROP COLUMN updated_at,
  DROP INDEX uq_tbef_team_season_formation,
  DROP INDEX idx_tbef_team_season_default,
  MODIFY team_id BIGINT UNSIGNED NOT NULL,
  MODIFY season_id BIGINT UNSIGNED NOT NULL,
  MODIFY matches_used INT UNSIGNED NOT NULL,
  ADD PRIMARY KEY (team_id, season_id, formation),
  ADD CONSTRAINT chk_tbef_matches_positive CHECK (matches_used > 0),
  ADD CONSTRAINT fk_tbef_team_season
    FOREIGN KEY (team_id, season_id) REFERENCES team_seasons (team_id, season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE;

-- 이름·사진·포지션은 선수 ID로 조회하고, 표시 순서와 기본 포메이션은 계산해요.
-- 누락이 있는 출전 시간은 선정 기준에서 빼고 원본 fixture_lineups에만 보존해요.
ALTER TABLE team_best_eleven
  DROP PRIMARY KEY,
  DROP COLUMN id,
  DROP COLUMN slot_index,
  DROP COLUMN player_name,
  DROP COLUMN player_image,
  DROP COLUMN position_name,
  DROP COLUMN detailed_position_name,
  DROP COLUMN total_minutes,
  DROP COLUMN updated_at,
  DROP INDEX uq_tbe_team_season_formation_slot,
  DROP INDEX idx_tbe_team_season,
  MODIFY team_id BIGINT UNSIGNED NOT NULL,
  MODIFY season_id BIGINT UNSIGNED NOT NULL,
  MODIFY player_id BIGINT UNSIGNED NOT NULL,
  MODIFY starts INT UNSIGNED NOT NULL,
  ADD PRIMARY KEY (team_id, season_id, formation, slot_key),
  ADD UNIQUE KEY uq_tbe_formation_player (team_id, season_id, formation, player_id),
  ADD KEY idx_tbe_player (player_id),
  ADD CONSTRAINT chk_tbe_starts CHECK (starts > 0),
  ADD CONSTRAINT fk_tbe_formation
    FOREIGN KEY (team_id, season_id, formation)
    REFERENCES team_best_eleven_formations (team_id, season_id, formation)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT fk_tbe_player
    FOREIGN KEY (player_id) REFERENCES players (player_id)
    ON DELETE RESTRICT ON UPDATE CASCADE;
