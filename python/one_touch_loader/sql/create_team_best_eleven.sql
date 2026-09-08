-- 포메이션별 사용 경기 수와 자리별 선정 선수는 서로 다른 관계로 저장해요.
CREATE TABLE IF NOT EXISTS team_best_eleven_formations (
  team_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,
  formation VARCHAR(20) NOT NULL,
  matches_used INT UNSIGNED NOT NULL,
  PRIMARY KEY (team_id, season_id, formation),
  CONSTRAINT chk_tbef_matches_positive CHECK (matches_used > 0),
  CONSTRAINT fk_tbef_team_season
    FOREIGN KEY (team_id, season_id) REFERENCES team_seasons (team_id, season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS team_best_eleven (
  team_id BIGINT UNSIGNED NOT NULL,
  season_id BIGINT UNSIGNED NOT NULL,
  formation VARCHAR(20) NOT NULL,
  slot_key VARCHAR(10) NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  starts INT UNSIGNED NOT NULL,
  PRIMARY KEY (team_id, season_id, formation, slot_key),
  UNIQUE KEY uq_tbe_formation_player (team_id, season_id, formation, player_id),
  KEY idx_tbe_player (player_id),
  CONSTRAINT chk_tbe_starts CHECK (starts > 0),
  CONSTRAINT fk_tbe_formation
    FOREIGN KEY (team_id, season_id, formation)
    REFERENCES team_best_eleven_formations (team_id, season_id, formation)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_tbe_player
    FOREIGN KEY (player_id) REFERENCES players (player_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
