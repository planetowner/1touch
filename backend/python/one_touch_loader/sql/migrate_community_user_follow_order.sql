-- 기존 관계의 팔로우 시각은 알 수 없으므로 NULL로 남겨요. 새 관계는 앱에서 UTC 시각을 저장해요.
-- 관계 방향별로 시간과 회원 ID를 함께 정렬해 페이지 순서를 고정해요.
ALTER TABLE user_following_users
    ADD COLUMN created_at DATETIME(6) NULL,
    ADD KEY following_created (user_id, created_at, followed_user_id),
    ADD KEY followers_created (followed_user_id, created_at, user_id);
