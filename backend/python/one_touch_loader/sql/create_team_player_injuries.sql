-- 선수 정보는 players에서 읽고, 서로 다른 부상은 공급자의 sideline_id로 구분해요.
CREATE TABLE IF NOT EXISTS injury_types (
  type_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  PRIMARY KEY (type_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS team_player_injuries (
  sideline_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  type_id BIGINT UNSIGNED NOT NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  PRIMARY KEY (sideline_id),
  KEY idx_tpi_team_player (team_id, player_id),
  KEY idx_tpi_player (player_id),
  KEY idx_tpi_type (type_id),
  CONSTRAINT fk_tpi_team FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_tpi_player FOREIGN KEY (player_id) REFERENCES players (player_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_tpi_type FOREIGN KEY (type_id) REFERENCES injury_types (type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
