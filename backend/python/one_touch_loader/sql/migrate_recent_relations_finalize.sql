-- 사전 백업과 변환·동일성 검증을 통과한 뒤에만 기존 복사본을 없애요.
DROP TABLE team_highlights_cache;
DROP TABLE team_youtube_playlists;
DROP TABLE team_youtube_sources;
ALTER TABLE clubelo_ratings
    DROP COLUMN segment_id, DROP COLUMN source_url, DROP COLUMN source_sha256, DROP COLUMN fetched_at;
ALTER TABLE fixture_opta_shotmaps
    DROP COLUMN external_fixture_id, DROP COLUMN external_competition_id, DROP COLUMN external_season_id,
    DROP COLUMN source_url, DROP COLUMN home_count, DROP COLUMN away_count,
    ADD CONSTRAINT fk_opta_shotmap_source FOREIGN KEY (fixture_id) REFERENCES fixture_opta_sources(fixture_id) ON DELETE CASCADE;
ALTER TABLE fixture_opta_analyses
    DROP COLUMN external_fixture_id, DROP COLUMN external_competition_id, DROP COLUMN external_season_id,
    DROP COLUMN source_url, DROP COLUMN home_count, DROP COLUMN away_count,
    ADD CONSTRAINT fk_opta_analysis_source FOREIGN KEY (fixture_id) REFERENCES fixture_opta_sources(fixture_id) ON DELETE CASCADE;
ALTER TABLE fixture_player_stats
    ADD CONSTRAINT fk_fixture_player_stats_type FOREIGN KEY (stat_type_id) REFERENCES fixture_stat_types(stat_type_id);
