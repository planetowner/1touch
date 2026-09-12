INSERT INTO team_youtube_sources (
    team_id, team_name, channel_id, channel_url, source_mode,
    include_title_keywords, exclude_title_keywords, notes,
    max_candidate_items, is_active, created_at, updated_at
) VALUES
(52, 'AFC Bournemouth', 'UCeOCuVSSweaEj6oVtJZEKQw', 'https://www.youtube.com/@AFCBournemouth', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(19, 'Arsenal', 'UCpryVRk_VDudG8SHXgWcG0w', 'https://www.youtube.com/@arsenal', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(15, 'Aston Villa', 'UCICNP0mvtr0prFwGUQIABfQ', 'https://www.youtube.com/@avfcofficial', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(236, 'Brentford', 'UCAalMUm3LIf504ItA3rqfug', 'https://www.youtube.com/@BrentfordFC', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(78, 'Brighton & Hove Albion', 'UCf-cpC9WAdOsas19JHipukA', 'https://www.youtube.com/@officialbhafc', 'playlists', NULL, 'Premier League 2', NULL, 40, 1, NOW(), NOW()),
(27, 'Burnley', 'UChvUXuSDeEFSQZS8GcPMtkg', 'https://www.youtube.com/@burnleyofficial', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(18, 'Chelsea', 'UCU2PacFf99vhb3hNiYDmxww', 'https://www.youtube.com/@chelseafc', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(51, 'Crystal Palace', 'UCWB9N0012fG6bGyj486Qxmg', 'https://www.youtube.com/@OfficialCPFC', 'channel_rules', 'Premier League Highlights, UEFA Conference League', NULL, 'playlist는 안 쓰고 채널 홈/업로드 기준으로 제목 검색', 40, 1, NOW(), NOW()),
(13, 'Everton', 'UCtK4QAczAN2mt2ow_jlGinQ', 'https://www.youtube.com/@Everton', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(11, 'Fulham', 'UC2VLfz92cTT8jHIFOecC-LA', 'https://www.youtube.com/@fulhamfc', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(71, 'Leeds United', 'UCyQcJHDN4uYfPa1DHzKVSnw', 'https://www.youtube.com/@LeedsUnited', 'channel_rules', 'Premier League highlights, FA Cup highlights', NULL, 'playlist는 안 쓰고 채널 홈/업로드 기준으로 제목 검색', 40, 1, NOW(), NOW()),
(8, 'Liverpool', 'UC9LQwHZoucFT94I2h6JOcjw', 'https://www.youtube.com/@LiverpoolFC', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(9, 'Manchester City', 'UCkzCjdRMrW2vXLx8mvPVLdQ', 'https://www.youtube.com/@mancity', 'playlists', NULL, NULL, 'playlist에 남자팀/여자팀 하이라이트가 섞일 수 있음', 40, 1, NOW(), NOW()),
(14, 'Manchester United', 'UC6yW44UGJJBvYTlfC7CRg2Q', 'https://www.youtube.com/@manutd', 'playlists', NULL, 'Extended Highlights', NULL, 40, 1, NOW(), NOW()),
(20, 'Newcastle United', 'UCywGl_BPp9QhD0uAcP2HsJw', 'https://www.youtube.com/@NUFC', 'playlists', NULL, 'EXTENDED Premier League Highlights', NULL, 40, 1, NOW(), NOW()),
(63, 'Nottingham Forest', 'UCyAxjuAr8f_BFDGCO3Htbxw', 'https://www.youtube.com/@NottinghamForestFC', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(3, 'Sunderland', 'UCrw-7k6yJc0EMJdf-0BAkoQ', 'https://www.youtube.com/@SunderlandAFC', 'playlists', 'Premier League Highlights', NULL, NULL, 40, 1, NOW(), NOW()),
(6, 'Tottenham Hotspur', 'UCEg25rdRZXg32iwai6N6l0w', 'https://www.youtube.com/@TottenhamHotspur', 'playlists', NULL, NULL, NULL, 40, 1, NOW(), NOW()),
(1, 'West Ham United', 'UCCNOsmurvpEit9paBOzWtUg', 'https://www.youtube.com/@westhamunited', 'channel_rules', 'Premier League highlights, FA Cup highlights', 'Premier League Extended Highlights', 'playlist는 안 쓰고 채널 홈/업로드 기준으로 제목 검색', 40, 1, NOW(), NOW()),
(29, 'Wolverhampton Wanderers', 'UCQ7Lqg5Czh5djGK6iOG53KQ', 'https://www.youtube.com/@OfficialWolvesVideo', 'channel_rules', 'Extended Highlights', NULL, 'playlist는 안 쓰고 채널 홈/업로드 기준으로 제목 검색', 40, 1, NOW(), NOW());

INSERT INTO team_youtube_playlists (
    team_id, playlist_name, playlist_id, playlist_url, is_active, created_at, updated_at
) VALUES
(52, 'Highlights', 'PLDSAlkBZMWj5N7tdhX2uI5YkLFnD3V7VI', 'https://www.youtube.com/playlist?list=PLDSAlkBZMWj5N7tdhX2uI5YkLFnD3V7VI', 1, NOW(), NOW()),
(19, 'Highlights', 'PLvuwbYTkUzHcWbmTUwc_TDprJHvpOZQCV', 'https://www.youtube.com/playlist?list=PLvuwbYTkUzHcWbmTUwc_TDprJHvpOZQCV', 1, NOW(), NOW()),
(15, 'Highlights', 'PLiR0-7AEE2Hotf1U_U7a2rO53BgZUjcNq', 'https://www.youtube.com/playlist?list=PLiR0-7AEE2Hotf1U_U7a2rO53BgZUjcNq', 1, NOW(), NOW()),
(236, 'Highlights', 'PL62gtN0myLZYvjKuGPObM3sMeWml3FbQp', 'https://www.youtube.com/playlist?list=PL62gtN0myLZYvjKuGPObM3sMeWml3FbQp', 1, NOW(), NOW()),
(78, 'Highlights', 'PLU4NF13Grb9HXwr0ijDpE1G7gxdbRuOWO', 'https://www.youtube.com/playlist?list=PLU4NF13Grb9HXwr0ijDpE1G7gxdbRuOWO', 1, NOW(), NOW()),
(27, 'Highlights', 'PLT0NSkVOxxL-iyqnA1hXAR_xz3hq4ko2u', 'https://www.youtube.com/playlist?list=PLT0NSkVOxxL-iyqnA1hXAR_xz3hq4ko2u', 1, NOW(), NOW()),
(18, '2-Minute Premier League Highlights | 2025/26', 'PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1', 'https://www.youtube.com/playlist?list=PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1', 1, NOW(), NOW()),
(18, 'FA Cup Highlights | 2025/26', 'PLx6bGx4zt6EkvHD82pE-_TyduEY79ZQ_q', 'https://www.youtube.com/playlist?list=PLx6bGx4zt6EkvHD82pE-_TyduEY79ZQ_q', 1, NOW(), NOW()),
(13, 'Highlights', 'PLkB7IpRClaTIq6_zXWIhIFd-5qfqrtPLk', 'https://www.youtube.com/playlist?list=PLkB7IpRClaTIq6_zXWIhIFd-5qfqrtPLk', 1, NOW(), NOW()),
(11, 'Highlights', 'PLY8T1xH7hxoqgrkF1OIxjZpum7ylgr9g_', 'https://www.youtube.com/playlist?list=PLY8T1xH7hxoqgrkF1OIxjZpum7ylgr9g_', 1, NOW(), NOW()),
(8, 'Highlights', 'PLR8DItC4f5xtq0Th2aa6KyiraLty-cSTG', 'https://www.youtube.com/playlist?list=PLR8DItC4f5xtq0Th2aa6KyiraLty-cSTG', 1, NOW(), NOW()),
(9, 'Highlights', 'PLp_A7BZlpSOcsW23OdEvrC1KnhtrOpb0v', 'https://www.youtube.com/playlist?list=PLp_A7BZlpSOcsW23OdEvrC1KnhtrOpb0v', 1, NOW(), NOW()),
(14, 'Highlights', 'PL5-QUghxmluLRUTCh-umhonToE-X_Dnu-', 'https://www.youtube.com/playlist?list=PL5-QUghxmluLRUTCh-umhonToE-X_Dnu-', 1, NOW(), NOW()),
(20, 'Highlights', 'PLb39HY4ZwBVkhGGO_Yxn3KsUeiEmUthE2', 'https://www.youtube.com/playlist?list=PLb39HY4ZwBVkhGGO_Yxn3KsUeiEmUthE2', 1, NOW(), NOW()),
(63, 'Highlights', 'PLooQvgG3c7czcVlEp3f-wfZL-n2mTgyLS', 'https://www.youtube.com/playlist?list=PLooQvgG3c7czcVlEp3f-wfZL-n2mTgyLS', 1, NOW(), NOW()),
(3, 'Highlights', 'PLuRgWp9ON5vr9yIJna4WeCeQSm4dTGhFl', 'https://www.youtube.com/playlist?list=PLuRgWp9ON5vr9yIJna4WeCeQSm4dTGhFl', 1, NOW(), NOW()),
(6, 'Highlights', 'PLCQm3OPgov-if9jjzK-aoOLZ7C79b18k1', 'https://www.youtube.com/playlist?list=PLCQm3OPgov-if9jjzK-aoOLZ7C79b18k1', 1, NOW(), NOW());