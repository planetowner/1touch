-- 최신 계산의 입력 기준 시각과 완료 시각을 구분해 저장해요.
CREATE TABLE IF NOT EXISTS player_indicator_refresh (
    id TINYINT UNSIGNED NOT NULL,
    input_sha256 CHAR(64) DEFAULT NULL,
    as_of DATETIME(6) DEFAULT NULL,
    calculated_at DATETIME(6) DEFAULT NULL,
    checked_at DATETIME(6) DEFAULT NULL,
    player_count INT UNSIGNED NOT NULL DEFAULT 0,
    read_seconds DOUBLE DEFAULT NULL,
    calculation_seconds DOUBLE DEFAULT NULL,
    PRIMARY KEY (id),
    CONSTRAINT chk_player_indicator_refresh_id CHECK (id=1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO player_indicator_refresh (id) VALUES (1);

-- 전체 비교 집단의 결과를 한 번에 교체하고 API는 선수 한 명만 읽어요.
CREATE TABLE IF NOT EXISTS player_indicator_snapshots (
    player_id BIGINT UNSIGNED NOT NULL,
    team_id BIGINT UNSIGNED NOT NULL,
    season_id BIGINT UNSIGNED NOT NULL,
    payload JSON NOT NULL,
    PRIMARY KEY (player_id),
    CONSTRAINT fk_player_indicator_player FOREIGN KEY (player_id)
        REFERENCES players (player_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_player_indicator_team FOREIGN KEY (team_id)
        REFERENCES teams (team_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_player_indicator_season FOREIGN KEY (season_id)
        REFERENCES seasons (season_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
