-- 같은 시즌의 모든 대회를 합친 결과라 대회별 season_id 대신 기존 season_name 규칙을 써요.
CREATE TABLE IF NOT EXISTS player_season_positions (
    season_name VARCHAR(120) NOT NULL,
    player_id BIGINT UNSIGNED NOT NULL,
    position_group_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (season_name, player_id),
    CONSTRAINT fk_player_season_position_player FOREIGN KEY (player_id)
        REFERENCES players (player_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_player_season_position_group CHECK (position_group_id IN (24,25,26,27))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
