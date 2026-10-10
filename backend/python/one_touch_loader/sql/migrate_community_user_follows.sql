-- 회원 팔로우 관계는 중복 없이 저장하고, 탈퇴하면 양쪽 관계를 함께 지워요.
CREATE TABLE user_following_users (
    user_id BIGINT UNSIGNED NOT NULL,
    followed_user_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (user_id, followed_user_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (followed_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT no_self_follow CHECK (user_id <> followed_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
