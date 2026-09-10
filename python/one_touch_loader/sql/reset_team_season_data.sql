-- 과거 스키마의 전체 초기화 기록이에요. 현재 DB에는 실행하지 않아요.
-- 이후 경기 상세·attributes·Understat 변경으로 대상 테이블 구성이 달라졌어요.
-- 팀과 시즌을 다시 적재하기 전에 연결된 축구 데이터를 함께 비워요.
UPDATE user_profiles
SET favorite_team_id = NULL
WHERE favorite_team_id IS NOT NULL;

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE fixture_formations;
TRUNCATE TABLE fixture_lineups;
TRUNCATE TABLE fixture_team_stats_raw;
TRUNCATE TABLE fixtures;
TRUNCATE TABLE aggregates;
TRUNCATE TABLE player_team_honours;
TRUNCATE TABLE player_wages;
TRUNCATE TABLE stage_groups;
TRUNCATE TABLE stages;
TRUNCATE TABLE standings;
TRUNCATE TABLE team_attribute_group_scores;
TRUNCATE TABLE team_attribute_features;
TRUNCATE TABLE team_attribute_regression_weights;
TRUNCATE TABLE team_attribute_regression_models;
TRUNCATE TABLE team_best_eleven;
TRUNCATE TABLE team_best_eleven_formations;
TRUNCATE TABLE team_highlights_cache;
TRUNCATE TABLE team_player_injuries;
TRUNCATE TABLE team_seasons;
TRUNCATE TABLE team_squad_members;
TRUNCATE TABLE team_transfers;
TRUNCATE TABLE team_youtube_playlists;
TRUNCATE TABLE team_youtube_sources;
TRUNCATE TABLE transfer_windows;
TRUNCATE TABLE understat_season_map;
TRUNCATE TABLE understat_team_map;
TRUNCATE TABLE user_following_teams;
TRUNCATE TABLE xg_standings;
TRUNCATE TABLE xg_standings_calibration;
TRUNCATE TABLE seasons;
TRUNCATE TABLE teams;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'fixture_formations' AS table_name, COUNT(*) AS row_count FROM fixture_formations
UNION ALL SELECT 'fixture_lineups', COUNT(*) FROM fixture_lineups
UNION ALL SELECT 'fixture_team_stats_raw', COUNT(*) FROM fixture_team_stats_raw
UNION ALL SELECT 'fixtures', COUNT(*) FROM fixtures
UNION ALL SELECT 'aggregates', COUNT(*) FROM aggregates
UNION ALL SELECT 'player_team_honours', COUNT(*) FROM player_team_honours
UNION ALL SELECT 'player_wages', COUNT(*) FROM player_wages
UNION ALL SELECT 'stage_groups', COUNT(*) FROM stage_groups
UNION ALL SELECT 'stages', COUNT(*) FROM stages
UNION ALL SELECT 'standings', COUNT(*) FROM standings
UNION ALL SELECT 'team_attribute_group_scores', COUNT(*) FROM team_attribute_group_scores
UNION ALL SELECT 'team_attribute_features', COUNT(*) FROM team_attribute_features
UNION ALL SELECT 'team_attribute_regression_weights', COUNT(*) FROM team_attribute_regression_weights
UNION ALL SELECT 'team_attribute_regression_models', COUNT(*) FROM team_attribute_regression_models
UNION ALL SELECT 'team_best_eleven', COUNT(*) FROM team_best_eleven
UNION ALL SELECT 'team_best_eleven_formations', COUNT(*) FROM team_best_eleven_formations
UNION ALL SELECT 'team_highlights_cache', COUNT(*) FROM team_highlights_cache
UNION ALL SELECT 'team_player_injuries', COUNT(*) FROM team_player_injuries
UNION ALL SELECT 'team_seasons', COUNT(*) FROM team_seasons
UNION ALL SELECT 'team_squad_members', COUNT(*) FROM team_squad_members
UNION ALL SELECT 'team_transfers', COUNT(*) FROM team_transfers
UNION ALL SELECT 'team_youtube_playlists', COUNT(*) FROM team_youtube_playlists
UNION ALL SELECT 'team_youtube_sources', COUNT(*) FROM team_youtube_sources
UNION ALL SELECT 'transfer_windows', COUNT(*) FROM transfer_windows
UNION ALL SELECT 'understat_season_map', COUNT(*) FROM understat_season_map
UNION ALL SELECT 'understat_team_map', COUNT(*) FROM understat_team_map
UNION ALL SELECT 'user_following_teams', COUNT(*) FROM user_following_teams
UNION ALL SELECT 'xg_standings', COUNT(*) FROM xg_standings
UNION ALL SELECT 'xg_standings_calibration', COUNT(*) FROM xg_standings_calibration
UNION ALL SELECT 'seasons', COUNT(*) FROM seasons
UNION ALL SELECT 'teams', COUNT(*) FROM teams;

SELECT 'competitions' AS preserved_table, COUNT(*) AS row_count FROM competitions
UNION ALL SELECT 'countries', COUNT(*) FROM countries
UNION ALL SELECT 'positions', COUNT(*) FROM positions
UNION ALL SELECT 'stage_types', COUNT(*) FROM stage_types
UNION ALL SELECT 'players', COUNT(*) FROM players
UNION ALL SELECT 'player_external_ids', COUNT(*) FROM player_external_ids
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'posts', COUNT(*) FROM posts
UNION ALL SELECT 'understat_league_map', COUNT(*) FROM understat_league_map;
