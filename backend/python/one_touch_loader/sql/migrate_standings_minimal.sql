-- 현재 standings는 0행이라 화면에서 쓰지 않는 열을 옮기지 않고 최소 구조로 다시 만들어요.
DROP TABLE standings;

CREATE TABLE standings (
  season_id        BIGINT UNSIGNED NOT NULL,
  team_id          BIGINT UNSIGNED NOT NULL,
  position         TINYINT UNSIGNED NOT NULL,
  previous_position TINYINT UNSIGNED NULL,
  won              TINYINT UNSIGNED NOT NULL,
  draw             TINYINT UNSIGNED NOT NULL,
  lost             TINYINT UNSIGNED NOT NULL,
  goals_for        SMALLINT UNSIGNED NOT NULL,
  goals_against    SMALLINT UNSIGNED NOT NULL,
  points           SMALLINT UNSIGNED NOT NULL,

  PRIMARY KEY (season_id, team_id),
  KEY idx_standings_team_season (team_id, season_id),

  CONSTRAINT fk_standings_team_season
    FOREIGN KEY (team_id, season_id)
    REFERENCES team_seasons (team_id, season_id)
    ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
