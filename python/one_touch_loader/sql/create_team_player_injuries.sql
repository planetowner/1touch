CREATE TABLE IF NOT EXISTS team_player_injuries (
  sideline_id BIGINT NOT NULL PRIMARY KEY,
  team_id BIGINT NOT NULL,
  player_id BIGINT NOT NULL,
  type_id BIGINT NULL,

  category VARCHAR(50) NULL,
  type_name VARCHAR(255) NULL,
  player_name VARCHAR(255) NULL,

  start_date DATE NULL,
  end_date DATE NULL,
  games_missed INT NULL,
  completed TINYINT(1) NOT NULL DEFAULT 0,

  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_seen_at DATETIME NOT NULL,

  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,

  KEY idx_tpi_team_active (team_id, is_active),
  KEY idx_tpi_player_active (player_id, is_active),
  KEY idx_tpi_team_completed (team_id, completed),
  KEY idx_tpi_last_seen (last_seen_at),
  KEY idx_tpi_team_player (team_id, player_id)
);