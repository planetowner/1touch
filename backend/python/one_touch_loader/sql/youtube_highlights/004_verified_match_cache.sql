-- 기존 캐시와 키는 보존하고 경기 연결·국가 제한 메타데이터만 더해요.
ALTER TABLE team_highlights_cache
    ADD COLUMN match_key VARCHAR(100) NULL,
    ADD COLUMN match_data JSON NULL,
    ADD COLUMN video_data JSON NULL;
