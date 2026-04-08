CREATE TABLE IF NOT EXISTS team_squad (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  team_id         BIGINT NOT NULL,
  player_id       BIGINT NOT NULL,
  player_name     VARCHAR(255) NULL,
  transfer_id     BIGINT NULL,
  position_id     INT NULL,
  position_name   VARCHAR(100) NULL,
  jersey_number   INT NULL,
  start_date      DATE NULL,
  end_date        DATE NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ts_team_player (team_id, player_id),
  KEY idx_ts_team (team_id),
  KEY idx_ts_player (player_id),
  KEY idx_ts_transfer (transfer_id)
);
