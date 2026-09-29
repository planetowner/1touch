-- 기존 회원은 개인정보 수정 화면에서 닉네임을 직접 정해요.
ALTER TABLE users ADD COLUMN display_name VARCHAR(100) NULL AFTER username;

-- 두 항목의 변경 이력을 따로 세고, 사용자 행 잠금으로 동시 변경을 직렬화해요.
CREATE TABLE user_profile_changes (
    change_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    change_type ENUM('display_name','favorite_team') NOT NULL,
    changed_at DATETIME(6) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    KEY user_change_window (user_id, change_type, changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 이전 7일 제한의 마지막 최애팀 변경도 새 14일 횟수에 포함해요.
INSERT INTO user_profile_changes (user_id,change_type,changed_at)
SELECT user_id,'favorite_team',favorite_changed_at FROM users WHERE favorite_changed_at IS NOT NULL;
