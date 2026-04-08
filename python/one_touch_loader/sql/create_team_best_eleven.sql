CREATE TABLE IF NOT EXISTS team_best_eleven (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  team_id         BIGINT NOT NULL,
  season_id       BIGINT NOT NULL,
  formation       VARCHAR(20) NOT NULL,      -- 최다 사용 포메이션
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

  UNIQUE KEY uq_tbe_team_season_slot (team_id, season_id, slot_key),
  KEY idx_tbe_team_season (team_id, season_id)
);
