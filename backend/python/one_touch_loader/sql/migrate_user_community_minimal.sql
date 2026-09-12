-- 격리 MySQL에서 저장 경로와 검증기를 확인했어요. 운영 적용은 백업 실행기를 사용해요.
-- 사전 검증에서 기존 회원·커뮤니티 5개 테이블이 모두 비었을 때만 실행해요.
-- 새 시각은 UTC DATETIME으로 저장해 서버의 EDT 설정에 영향을 받지 않아요.
DROP TABLE post_reports;
DROP TABLE posts;
DROP TABLE user_following_teams;
DROP TABLE user_profiles;
DROP TABLE users;

CREATE TABLE users (
    user_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) COLLATE utf8mb4_0900_as_ci NULL UNIQUE,
    first_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    timezone VARCHAR(64) NULL,
    favorite_team_id BIGINT UNSIGNED NULL,
    favorite_changed_at DATETIME(6) NULL,
    created_at DATETIME(6) NOT NULL,
    FOREIGN KEY (favorite_team_id) REFERENCES teams(team_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 소셜 공급자 이메일과 이메일 로그인 계정을 자동으로 합치지 않아요.
-- 이메일은 인증·복구용이에요. 비밀번호 로그인은 users의 username과 이 해시를 사용해요.
CREATE TABLE user_email_credentials (
    user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    email VARCHAR(254) COLLATE utf8mb4_0900_as_ci NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_social_identities (
    provider ENUM('google','apple','kakao') NOT NULL,
    subject VARCHAR(255) COLLATE utf8mb4_bin NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (provider, subject),
    UNIQUE KEY one_identity_per_provider (user_id, provider),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 원본 세션 토큰은 응답으로 한 번만 전달하고 DB에는 해시만 보관해요.
CREATE TABLE user_sessions (
    token_hash BINARY(32) NOT NULL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    KEY session_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE email_verification_codes (
    challenge_hash BINARY(32) NOT NULL PRIMARY KEY,
    email VARCHAR(254) COLLATE utf8mb4_0900_as_ci NOT NULL,
    purpose ENUM('signup','password_reset') NOT NULL,
    code_hash BINARY(32) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
    UNIQUE KEY one_current_email_code (email, purpose)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 비밀번호 대입과 인증 메일 반복 발송을 제한하는 인증 요청 횟수예요.
CREATE TABLE api_rate_limits (
    scope_hash BINARY(32) NOT NULL PRIMARY KEY,
    window_started_at DATETIME(6) NOT NULL,
    attempts INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_following_teams (
    user_id BIGINT UNSIGNED NOT NULL,
    competition_id BIGINT UNSIGNED NOT NULL,
    team_id BIGINT UNSIGNED NOT NULL,
    position TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, team_id),
    UNIQUE KEY one_team_per_league (user_id, competition_id),
    UNIQUE KEY team_follow_order (user_id, position),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (competition_id) REFERENCES competitions(competition_id),
    FOREIGN KEY (team_id) REFERENCES teams(team_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_following_players (
    user_id BIGINT UNSIGNED NOT NULL,
    player_id BIGINT UNSIGNED NOT NULL,
    position INT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, player_id),
    UNIQUE KEY player_follow_order (user_id, position),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (player_id) REFERENCES players(player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE posts (
    post_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    team_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    category ENUM('general','analysis','news') NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    FOREIGN KEY (team_id) REFERENCES teams(team_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    KEY team_posts (team_id, created_at, post_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 좋아요 수와 BEST 여부는 이 관계의 개수로 계산해요.
CREATE TABLE post_likes (
    post_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (post_id, user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE post_comments (
    comment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    reply_to_id BIGINT UNSIGNED NULL,
    body TEXT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    FOREIGN KEY (post_id) REFERENCES posts(post_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (reply_to_id) REFERENCES post_comments(comment_id),
    KEY post_comment_order (post_id, comment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE comment_likes (
    comment_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (comment_id, user_id),
    FOREIGN KEY (comment_id) REFERENCES post_comments(comment_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 작성 중 업로드한 파일은 post_id가 없어요. 게시 시 같은 작성자의 첨부만 연결해요.
-- 파일은 R2의 내부 키, 링크는 원본 URL을 저장하고 영구 공개 주소는 만들지 않아요.
CREATE TABLE post_attachments (
    attachment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    post_id BIGINT UNSIGNED NULL,
    position TINYINT UNSIGNED NULL,
    object_key VARCHAR(255) COLLATE utf8mb4_bin NULL UNIQUE,
    link_url VARCHAR(2048) NULL,
    content_type VARCHAR(100) NULL,
    byte_size BIGINT UNSIGNED NULL,
    created_at DATETIME(6) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id),
    UNIQUE KEY attachment_order (post_id, position),
    CHECK ((object_key IS NOT NULL AND link_url IS NULL AND content_type IS NOT NULL AND byte_size IS NOT NULL)
        OR (object_key IS NULL AND link_url IS NOT NULL AND content_type IS NULL AND byte_size IS NULL)),
    CHECK ((post_id IS NULL AND position IS NULL) OR (post_id IS NOT NULL AND position IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 경기마다 채팅방 하나이므로 별도 방 테이블 없이 경기 ID로 묶어요.
CREATE TABLE fixture_chat_messages (
    message_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    fixture_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    body TEXT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    FOREIGN KEY (fixture_id) REFERENCES fixtures(fixture_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    KEY fixture_message_order (fixture_id, message_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE content_reports (
    report_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    post_id BIGINT UNSIGNED NULL,
    comment_id BIGINT UNSIGNED NULL,
    message_id BIGINT UNSIGNED NULL,
    reason VARCHAR(500) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (post_id) REFERENCES posts(post_id),
    FOREIGN KEY (comment_id) REFERENCES post_comments(comment_id),
    FOREIGN KEY (message_id) REFERENCES fixture_chat_messages(message_id),
    CHECK ((post_id IS NOT NULL) + (comment_id IS NOT NULL) + (message_id IS NOT NULL) = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
