-- Google 연결은 회원별로, 경기 구독은 팀별로 보관해요.
CREATE TABLE IF NOT EXISTS user_calendar_connections (
    user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    google_subject VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    refresh_token TEXT NOT NULL,
    calendar_id VARCHAR(1024) NOT NULL,
    last_synced_at DATETIME NULL,
    last_error VARCHAR(64) NULL,
    CONSTRAINT fk_calendar_connection_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS user_calendar_teams (
    user_id BIGINT UNSIGNED NOT NULL,
    team_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, team_id),
    CONSTRAINT fk_calendar_team_connection FOREIGN KEY (user_id)
        REFERENCES user_calendar_connections(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_calendar_team_team FOREIGN KEY (team_id)
        REFERENCES teams(team_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
