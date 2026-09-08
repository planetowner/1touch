-- 대표 포메이션 하나만 저장하던 Best Eleven 스키마를 한 번만 이전해요.
-- 이미 적용된 과거 이력이며 새 최소 스키마에는 실행하지 않아요.
-- 현재 DB 정리는 run_best_eleven_minimal_migration.ps1을 사용해요.

ALTER TABLE team_best_eleven
  DROP INDEX uq_tbe_team_season_slot,
  ADD UNIQUE KEY uq_tbe_team_season_formation_slot
    (team_id, season_id, formation, slot_key);

CREATE TABLE IF NOT EXISTS team_best_eleven_formations (
  id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
  team_id             BIGINT NOT NULL,
  season_id           BIGINT NOT NULL,
  formation           VARCHAR(20) NOT NULL,
  matches_used        INT NOT NULL,
  total_valid_matches INT NOT NULL,
  is_default          TINYINT(1) NOT NULL DEFAULT 0,

  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP,

  UNIQUE KEY uq_tbef_team_season_formation
    (team_id, season_id, formation),
  KEY idx_tbef_team_season_default
    (team_id, season_id, is_default),

  CONSTRAINT chk_tbef_matches
    CHECK (matches_used > 0 AND total_valid_matches >= matches_used),
  CONSTRAINT chk_tbef_default
    CHECK (is_default IN (0, 1))
);
