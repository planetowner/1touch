-- 같은 시즌에 주장이 교체되거나 부주장이 여럿인 경우를 모두 기록해요.
-- 시즌 중 떠난 선수도 이력에 남을 수 있어 명단 대신 팀·시즌과 선수를 참조해요.
CREATE TABLE IF NOT EXISTS team_leadership_assignments (
  team_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  leadership_role ENUM('captain', 'vice_captain') NOT NULL,
  PRIMARY KEY (team_id, season_id, leadership_role, player_id),
  KEY idx_team_leadership_player (player_id),
  CONSTRAINT fk_team_leadership_team_season
    FOREIGN KEY (team_id, season_id) REFERENCES team_seasons(team_id, season_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_team_leadership_player
    FOREIGN KEY (player_id) REFERENCES players(player_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
