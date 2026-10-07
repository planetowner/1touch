-- 언어 정보가 없던 글·초안·채팅은 요청한 정책에 따라 한국어 공간에 배정해요.
-- 이후 저장은 API가 언어를 반드시 전달하며, 기본값으로 언어 누락을 숨기지 않아요.
ALTER TABLE posts
    ADD COLUMN language ENUM('ko','en','zh','ja') NOT NULL DEFAULT 'ko' AFTER team_id,
    DROP INDEX team_posts,
    ADD KEY team_posts (team_id, language, created_at, post_id);
ALTER TABLE posts ALTER COLUMN language DROP DEFAULT;

ALTER TABLE fixture_chat_messages
    ADD COLUMN language ENUM('ko','en','zh','ja') NOT NULL DEFAULT 'ko' AFTER fixture_id,
    DROP INDEX fixture_message_order,
    ADD KEY fixture_message_order (fixture_id, language, message_id);
ALTER TABLE fixture_chat_messages ALTER COLUMN language DROP DEFAULT;
