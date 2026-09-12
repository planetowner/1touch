CREATE TABLE player_wages (
  team_id                    BIGINT UNSIGNED NOT NULL,
  season_id                  BIGINT UNSIGNED NOT NULL,
  player_id                  BIGINT UNSIGNED NOT NULL,
  estimated_weekly_gross_eur INT UNSIGNED NOT NULL,

  PRIMARY KEY (team_id, season_id, player_id),
  KEY idx_player_wages_player (player_id),

  CONSTRAINT fk_player_wages_team_season
    FOREIGN KEY (team_id, season_id)
    REFERENCES team_seasons (team_id, season_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_player_wages_player
    FOREIGN KEY (player_id) REFERENCES players (player_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
