-- 커뮤니티만 앱 알림함에 노출하고, 모든 종류의 푸시는 같은 발송 기록을 사용해요.
CREATE TABLE IF NOT EXISTS user_notification_preferences (
    user_id BIGINT UNSIGNED NOT NULL,
    scope ENUM('community','team','player') NOT NULL,
    subject_id BIGINT UNSIGNED NOT NULL,
    preferences JSON NOT NULL,
    PRIMARY KEY (user_id,scope,subject_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_push_devices (
    device_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    session_token_hash BINARY(32) NOT NULL,
    token_hash BINARY(32) NOT NULL UNIQUE,
    token TEXT NOT NULL,
    platform ENUM('android','ios') NOT NULL,
    locale VARCHAR(20) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (session_token_hash) REFERENCES user_sessions(token_hash) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_notifications (
    notification_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    event_key VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    kind VARCHAR(40) CHARACTER SET ascii NOT NULL,
    scope ENUM('community','team','player') NOT NULL,
    subject_ids JSON NOT NULL,
    payload JSON NOT NULL,
    fixture_id BIGINT UNSIGNED NULL,
    post_id BIGINT UNSIGNED NULL,
    comment_id BIGINT UNSIGNED NULL,
    actor_id BIGINT UNSIGNED NULL,
    created_at DATETIME(6) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    read_at DATETIME(6) NULL,
    cancelled_at DATETIME(6) NULL,
    UNIQUE KEY notification_event (user_id,event_key),
    KEY notification_inbox (user_id,scope,notification_id),
    KEY notification_fixture (fixture_id,event_key),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(post_id) ON DELETE CASCADE,
    FOREIGN KEY (comment_id) REFERENCES post_comments(comment_id) ON DELETE CASCADE,
    FOREIGN KEY (actor_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notification_push_deliveries (
    notification_id BIGINT UNSIGNED NOT NULL,
    device_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status ENUM('pending','sent','failed','skipped') NOT NULL DEFAULT 'pending',
    attempts INT UNSIGNED NOT NULL DEFAULT 0,
    next_attempt_at DATETIME(6) NOT NULL,
    last_error VARCHAR(64) NULL,
    PRIMARY KEY (notification_id,device_id),
    KEY push_pending (status,next_attempt_at),
    FOREIGN KEY (notification_id) REFERENCES user_notifications(notification_id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES user_push_devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notification_fixture_state (
    fixture_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    state_id INT NOT NULL,
    seen_keys JSON NOT NULL,
    current_keys JSON NOT NULL,
    sampled_at DATETIME(6) NOT NULL,
    FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
