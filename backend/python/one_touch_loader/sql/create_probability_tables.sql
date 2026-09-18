SET NAMES utf8mb4;

-- ClubElo는 초기 Probability 전력 자료예요. API 복구 후 수집 경로를 되돌릴 예정이에요.
-- 팀 ID 연결은 기존 team_external_ids의 provider='clubelo'를 함께 사용해요.
CREATE TABLE IF NOT EXISTS clubelo_ratings (
    team_id BIGINT UNSIGNED NOT NULL,
    rating_date DATE NOT NULL,
    elo DOUBLE NOT NULL,
    segment_id INT NOT NULL,
    source_url VARCHAR(255) NOT NULL,
    source_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
    fetched_at DATETIME(6) NOT NULL,
    PRIMARY KEY (team_id, rating_date),
    CONSTRAINT fk_clubelo_ratings_team FOREIGN KEY (team_id) REFERENCES teams(team_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 학습 입력·제외 경기·검증 결과·재학습 계수를 함께 보존해 계산 근거를 다시 볼 수 있어요.
CREATE TABLE IF NOT EXISTS probability_models (
    model_id CHAR(64) CHARACTER SET ascii NOT NULL,
    payload JSON NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (model_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 입력 또는 결과가 바뀐 재계산은 새 행이에요. 이미 공개한 같은 날 예측도 덮어쓰지 않아요.
CREATE TABLE IF NOT EXISTS probability_runs (
    run_id CHAR(64) CHARACTER SET ascii NOT NULL,
    model_id CHAR(64) CHARACTER SET ascii NOT NULL,
    season_id BIGINT UNSIGNED NOT NULL,
    as_of DATETIME(6) NOT NULL,
    payload JSON NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (run_id),
    KEY ix_probability_runs_season_date (season_id, as_of, created_at),
    CONSTRAINT fk_probability_runs_model FOREIGN KEY (model_id) REFERENCES probability_models(model_id),
    CONSTRAINT fk_probability_runs_season FOREIGN KEY (season_id) REFERENCES seasons(season_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
