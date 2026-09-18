-- 기존 자료를 옮겨 검증한 뒤에만 migrate_recent_relations_finalize.sql을 실행해요.
CREATE TABLE highlight_channels (
    channel_id VARCHAR(255) COLLATE utf8mb4_bin NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    source_type ENUM('club','competition') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE highlight_matches (
    match_key VARCHAR(100) COLLATE utf8mb4_bin NOT NULL PRIMARY KEY,
    fixture_id BIGINT UNSIGNED NULL,
    starting_at DATETIME NOT NULL,
    -- DFB·슈퍼컵처럼 fixtures에 없는 공식 경기만 경기당 한 번 보관해요. 점수는 저장하지 않아요.
    external_record JSON NULL,
    CONSTRAINT fk_highlight_match_fixture FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id),
    CONSTRAINT chk_highlight_match_record CHECK (
        (fixture_id IS NOT NULL AND external_record IS NULL) OR
        (fixture_id IS NULL AND external_record IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE highlight_videos (
    video_id VARCHAR(50) COLLATE utf8mb4_bin NOT NULL PRIMARY KEY,
    match_key VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
    channel_id VARCHAR(255) COLLATE utf8mb4_bin NOT NULL,
    title VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500) NULL,
    published_at DATETIME NOT NULL,
    duration_seconds INT UNSIGNED NOT NULL,
    region_restriction JSON NOT NULL,
    embeddable BOOLEAN NOT NULL,
    CONSTRAINT fk_highlight_video_match FOREIGN KEY (match_key) REFERENCES highlight_matches(match_key),
    CONSTRAINT fk_highlight_video_channel FOREIGN KEY (channel_id) REFERENCES highlight_channels(channel_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE team_highlights (
    team_id BIGINT UNSIGNED NOT NULL,
    video_id VARCHAR(50) COLLATE utf8mb4_bin NOT NULL,
    PRIMARY KEY (team_id,video_id),
    CONSTRAINT fk_team_highlight_team FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    CONSTRAINT fk_team_highlight_video FOREIGN KEY (video_id) REFERENCES highlight_videos(video_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE team_highlight_sync (
    team_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    checked_at DATETIME NOT NULL,
    CONSTRAINT fk_highlight_sync_team FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE probability_team_results (
    run_id CHAR(64) CHARACTER SET ascii NOT NULL,
    team_id BIGINT UNSIGNED NOT NULL,
    next_fixture_id BIGINT UNSIGNED NULL,
    payload JSON NOT NULL,
    PRIMARY KEY (run_id,team_id),
    CONSTRAINT fk_probability_result_run FOREIGN KEY (run_id) REFERENCES probability_runs(run_id) ON DELETE CASCADE,
    CONSTRAINT fk_probability_result_team FOREIGN KEY (team_id) REFERENCES teams(team_id),
    CONSTRAINT fk_probability_result_fixture FOREIGN KEY (next_fixture_id) REFERENCES fixtures(fixture_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE clubelo_sources (
    team_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    source_sha256 CHAR(64) CHARACTER SET ascii NOT NULL,
    fetched_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_clubelo_source_team FOREIGN KEY (team_id) REFERENCES teams(team_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_opta_sources (
    fixture_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    source_url VARCHAR(1000) NOT NULL,
    CONSTRAINT fk_opta_source_fixture FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
