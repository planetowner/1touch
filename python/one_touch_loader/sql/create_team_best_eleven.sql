CREATE TABLE IF NOT EXISTS team_best_eleven (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  team_id         BIGINT NOT NULL,
  season_id       BIGINT NOT NULL,
  formation       VARCHAR(20) NOT NULL,      -- 이 Best Eleven이 사용하는 포메이션
  slot_key        VARCHAR(10) NOT NULL,      -- formation_field 값 ("1:1", "2:3", ...)
  slot_index      TINYINT NOT NULL,          -- 0~10 (프론트 렌더링 순서)
  player_id       BIGINT NOT NULL,
  player_name     VARCHAR(255) NULL,
  player_image    VARCHAR(512) NULL,
  position_name   VARCHAR(50) NULL,
  detailed_position_name VARCHAR(100) NULL,
  starts          INT NOT NULL DEFAULT 0,
  total_minutes   INT NOT NULL DEFAULT 0,

  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,

  UNIQUE KEY uq_tbe_team_season_formation_slot
    (team_id, season_id, formation, slot_key),
  KEY idx_tbe_team_season (team_id, season_id)
);

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
