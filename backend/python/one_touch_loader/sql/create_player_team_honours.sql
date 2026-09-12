CREATE TABLE IF NOT EXISTS player_team_honours (
  player_id BIGINT UNSIGNED NOT NULL,
  team_id   BIGINT UNSIGNED NOT NULL,
  competition_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,

  PRIMARY KEY (player_id, team_id, competition_id, season_id),
  KEY idx_player_team_honours_team (team_id),
  KEY idx_player_team_honours_competition (competition_id),
  KEY idx_player_team_honours_season (season_id),

  CONSTRAINT fk_player_team_honours_player
    FOREIGN KEY (player_id) REFERENCES players(player_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
