-- 기존 fixtures는 국내 컵 일부 팀만 포함해 전체 대진표를 별도로 저장해요.
CREATE TABLE IF NOT EXISTS tournament_brackets (
    season_id BIGINT UNSIGNED NOT NULL,
    input_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
    payload JSON NOT NULL,
    fetched_at DATETIME(6) NOT NULL,
    PRIMARY KEY (season_id),
    CONSTRAINT fk_tournament_brackets_season FOREIGN KEY (season_id) REFERENCES seasons(season_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
