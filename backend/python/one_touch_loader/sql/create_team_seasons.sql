-- Sportmonks 대회 시즌에 참가한 DB 팀을 연결해요.
-- 참가 대회는 seasons.competition_id로 확인해요.
CREATE TABLE IF NOT EXISTS team_seasons (
  team_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (team_id, season_id),
  KEY idx_team_seasons_season (season_id),
  CONSTRAINT fk_team_seasons_team
    FOREIGN KEY (team_id) REFERENCES teams(team_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_team_seasons_season
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
);
