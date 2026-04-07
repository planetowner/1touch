-- Chelsea league playlist id 변경 반영
UPDATE team_youtube_playlists
SET
    playlist_name = '2-Minute Premier League Highlights | 2025/26',
    playlist_id = 'PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1',
    playlist_url = 'https://www.youtube.com/playlist?list=PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1',
    updated_at = NOW()
WHERE team_id = 18
  AND playlist_id = 'PLx6bGx4zt6EkJDWF_RT9-KrlsppGLrulL';

-- 혹시 기존 row가 없을 경우 대비용 예시
-- INSERT INTO team_youtube_playlists (
--     team_id, playlist_name, playlist_id, playlist_url, is_active, created_at, updated_at
-- ) VALUES (
--     18,
--     '2-Minute Premier League Highlights | 2025/26',
--     'PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1',
--     'https://www.youtube.com/playlist?list=PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1',
--     1,
--     NOW(),
--     NOW()
-- );

-- Crystal Palace를 channel_rules로 확정
UPDATE team_youtube_sources
SET source_mode = 'channel_rules',
    include_title_keywords = 'Premier League Highlights, UEFA Conference League',
    exclude_title_keywords = NULL,
    notes = 'playlist는 안 쓰고 채널 홈/업로드 기준으로 제목 검색',
    updated_at = NOW()
WHERE team_id = 51;

-- 맨유는 Extended Highlights 제외
UPDATE team_youtube_sources
SET exclude_title_keywords = 'Extended Highlights',
    updated_at = NOW()
WHERE team_id = 14;

-- West Ham / Leeds는 잡영상이 많아 업로드 조회 수를 더 늘리고 싶을 때 사용
-- UPDATE team_youtube_sources
-- SET max_candidate_items = 80,
--     updated_at = NOW()
-- WHERE team_id IN (1, 71);

-- 맨시티를 임시 비활성화하고 싶을 때 사용
-- UPDATE team_youtube_sources
-- SET is_active = 0,
--     notes = 'playlist에 남자팀/여자팀 하이라이트가 섞여 있어 임시 비활성화',
--     updated_at = NOW()
-- WHERE team_id = 9;
--
-- DELETE FROM team_highlights_cache
-- WHERE team_id = 9;