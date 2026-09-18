-- 기준 표본은 한 번 저장한 뒤 유지해요. 시즌 점수 갱신으로 다시 만들지 않아요.
CREATE TABLE IF NOT EXISTS player_rating_references (
    competition_id BIGINT UNSIGNED NOT NULL,
    start_season_name VARCHAR(120) NOT NULL,
    end_season_name VARCHAR(120) NOT NULL,
    minimum_rated_matches SMALLINT UNSIGNED NOT NULL,
    frozen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (competition_id),
    CONSTRAINT fk_player_rating_reference_competition FOREIGN KEY (competition_id)
        REFERENCES competitions (competition_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 각 선수·리그·시즌이 한 표본이에요. 합계와 경기 수로 반올림 전 평균을 복원해요.
CREATE TABLE IF NOT EXISTS player_rating_reference_samples (
    competition_id BIGINT UNSIGNED NOT NULL,
    season_id BIGINT UNSIGNED NOT NULL,
    player_id BIGINT UNSIGNED NOT NULL,
    rated_matches SMALLINT UNSIGNED NOT NULL,
    rating_sum DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (competition_id, season_id, player_id),
    CONSTRAINT chk_player_rating_reference_matches CHECK (rated_matches >= 10),
    CONSTRAINT fk_player_rating_sample_reference FOREIGN KEY (competition_id)
        REFERENCES player_rating_references (competition_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_player_rating_sample_season FOREIGN KEY (season_id)
        REFERENCES seasons (season_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_player_rating_sample_player FOREIGN KEY (player_id)
        REFERENCES players (player_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS player_rating_scores (
    competition_id BIGINT UNSIGNED NOT NULL,
    season_id BIGINT UNSIGNED NOT NULL,
    player_id BIGINT UNSIGNED NOT NULL,
    rated_matches SMALLINT UNSIGNED NOT NULL,
    rating_sum DECIMAL(10,2) NOT NULL,
    percentile_score DECIMAL(13,10) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (season_id, player_id),
    -- 중반 전에는 1경기부터 저장해요. 중반 이후의 10경기 조건은 시즌 계산에서 적용해요.
    CONSTRAINT chk_player_rating_score_matches CHECK (rated_matches >= 1),
    CONSTRAINT chk_player_rating_score_range CHECK (percentile_score BETWEEN 0 AND 100),
    CONSTRAINT fk_player_rating_score_reference FOREIGN KEY (competition_id)
        REFERENCES player_rating_references (competition_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_player_rating_score_season FOREIGN KEY (season_id)
        REFERENCES seasons (season_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_player_rating_score_player FOREIGN KEY (player_id)
        REFERENCES players (player_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
