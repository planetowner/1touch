-- 같은 날에는 마지막 상태를 갱신하고, 이전 날짜의 기록은 그대로 남겨요.
CREATE TABLE IF NOT EXISTS player_ranking_snapshots (
    snapshot_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    season_name VARCHAR(120) NOT NULL,
    snapshot_date DATE NOT NULL,
    observed_at DATETIME(6) NOT NULL,
    input_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
    PRIMARY KEY (snapshot_id),
    UNIQUE KEY uq_player_ranking_day (season_name, snapshot_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 필터별 순위를 재현하려고 당시 평점 합계·경기 수·포지션을 저장해요.
-- 표시 점수는 순위 계산에 사용하지 않고 중복 저장하지 않아요.
CREATE TABLE IF NOT EXISTS player_ranking_snapshot_rows (
    snapshot_id BIGINT UNSIGNED NOT NULL,
    season_id BIGINT UNSIGNED NOT NULL,
    competition_id BIGINT UNSIGNED NOT NULL,
    player_id BIGINT UNSIGNED NOT NULL,
    rating_sum DECIMAL(10,2) NOT NULL,
    rated_matches SMALLINT UNSIGNED NOT NULL,
    position VARCHAR(2) NULL,
    PRIMARY KEY (snapshot_id, season_id, player_id),
    CONSTRAINT chk_ranking_snapshot_matches CHECK (rated_matches >= 1),
    CONSTRAINT chk_ranking_snapshot_position CHECK (position IN ('GK','DF','MF','FW')),
    CONSTRAINT fk_ranking_snapshot_row_snapshot FOREIGN KEY (snapshot_id)
        REFERENCES player_ranking_snapshots(snapshot_id) ON DELETE CASCADE,
    CONSTRAINT fk_ranking_snapshot_row_season FOREIGN KEY (season_id) REFERENCES seasons(season_id),
    CONSTRAINT fk_ranking_snapshot_row_competition FOREIGN KEY (competition_id) REFERENCES competitions(competition_id),
    CONSTRAINT fk_ranking_snapshot_row_player FOREIGN KEY (player_id) REFERENCES players(player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
