-- 첼시 리그 재생목록 ID 변경을 반영해요.
UPDATE team_youtube_playlists
SET
    playlist_name = '2-Minute Premier League Highlights | 2025/26',
    playlist_id = 'PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1',
    playlist_url = 'https://www.youtube.com/playlist?list=PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1',
    updated_at = NOW()
WHERE team_id = 18
  AND playlist_id = 'PLx6bGx4zt6EkJDWF_RT9-KrlsppGLrulL';

-- 크리스털 팰리스는 channel_rules 방식으로 확정해요.
UPDATE team_youtube_sources
SET source_mode = 'channel_rules',
    include_title_keywords = 'Premier League Highlights, UEFA Conference League',
    exclude_title_keywords = NULL,
    notes = 'playlist는 안 쓰고 채널 홈/업로드 기준으로 제목 검색',
    updated_at = NOW()
WHERE team_id = 51;

-- 맨체스터 유나이티드는 "Extended Highlights" 영상을 제외해요.
UPDATE team_youtube_sources
SET exclude_title_keywords = 'Extended Highlights',
    updated_at = NOW()
WHERE team_id = 14;
