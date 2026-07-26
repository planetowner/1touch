CREATE TABLE IF NOT EXISTS points_pace (
  league_id        INT NOT NULL,
  season_id        INT NOT NULL,
  team_id          INT NOT NULL,
  round_no         INT NOT NULL,
  match_date       DATETIME NOT NULL,
  cumulative_points INT NOT NULL,

  PRIMARY KEY (league_id, season_id, team_id, round_no),
  KEY idx_pp_league_season (league_id, season_id),
  KEY idx_pp_team (team_id)
);
