-- 최초 회원 마이그레이션을 다시 실행하지 않고 기존 행을 유지해 기능을 확장해요.
ALTER TABLE users ADD COLUMN suspended_until DATETIME(6) NULL;

-- 탈퇴한 작성자의 식별 관계만 끊고 글·답글·채팅 기록은 남겨요.
ALTER TABLE posts DROP FOREIGN KEY posts_ibfk_2,
    MODIFY user_id BIGINT UNSIGNED NULL,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN state ENUM('active','deleted','hidden') NOT NULL DEFAULT 'active',
    ADD COLUMN edited_at DATETIME(6) NULL;
ALTER TABLE post_comments DROP FOREIGN KEY post_comments_ibfk_2,
    MODIFY user_id BIGINT UNSIGNED NULL,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN state ENUM('active','deleted','hidden') NOT NULL DEFAULT 'active',
    ADD COLUMN edited_at DATETIME(6) NULL;
ALTER TABLE fixture_chat_messages DROP FOREIGN KEY fixture_chat_messages_ibfk_2,
    MODIFY user_id BIGINT UNSIGNED NULL,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN state ENUM('active','hidden') NOT NULL DEFAULT 'active';
ALTER TABLE post_attachments DROP FOREIGN KEY post_attachments_ibfk_1,
    MODIFY user_id BIGINT UNSIGNED NULL,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL;
ALTER TABLE content_reports DROP FOREIGN KEY content_reports_ibfk_1,
    MODIFY user_id BIGINT UNSIGNED NULL,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN resolution ENUM('dismissed','hidden') NULL,
    ADD COLUMN resolved_by BIGINT UNSIGNED NULL,
    ADD COLUMN resolved_at DATETIME(6) NULL,
    ADD FOREIGN KEY (resolved_by) REFERENCES users(user_id) ON DELETE SET NULL,
    ADD KEY pending_reports (resolution, report_id);

ALTER TABLE user_email_credentials DROP FOREIGN KEY user_email_credentials_ibfk_1,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE user_social_identities DROP FOREIGN KEY user_social_identities_ibfk_1,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE user_sessions DROP FOREIGN KEY user_sessions_ibfk_1,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE user_following_teams DROP FOREIGN KEY user_following_teams_ibfk_1,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE user_following_players DROP FOREIGN KEY user_following_players_ibfk_1,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE post_likes DROP FOREIGN KEY post_likes_ibfk_2,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;
ALTER TABLE comment_likes DROP FOREIGN KEY comment_likes_ibfk_2,
    ADD FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE;

-- 차단은 요청한 사람의 화면에만 적용해요. 양방향 관계를 만들지 않아요.
CREATE TABLE user_blocks (
    user_id BIGINT UNSIGNED NOT NULL,
    blocked_user_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, blocked_user_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (blocked_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CHECK (user_id <> blocked_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_avatars (
    user_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    object_key VARCHAR(255) COLLATE utf8mb4_bin NOT NULL UNIQUE,
    content_type VARCHAR(100) NOT NULL,
    byte_size BIGINT UNSIGNED NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- DB와 R2는 함께 롤백되지 않아요. 삭제할 키를 DB 변경과 함께 기록하고 별도 정리 명령에서 지워요.
CREATE TABLE media_deletions (
    object_key VARCHAR(255) COLLATE utf8mb4_bin NOT NULL PRIMARY KEY
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 모든 팀에 같은 안내를 보여 줘요. 팀별 복사본이나 일반 게시물의 좋아요·댓글 관계는 만들지 않아요.
CREATE TABLE community_rules (
    rules_id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    body TEXT NOT NULL,
    CHECK (rules_id = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 카카오의 SET 재전송을 구분하는 표식만 남겨요. 탈퇴한 회원 ID나 원문 토큰은 보관하지 않아요.
CREATE TABLE kakao_webhook_receipts (
    event_hash BINARY(32) NOT NULL PRIMARY KEY
) ENGINE=InnoDB;
