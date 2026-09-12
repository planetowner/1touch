DROP TABLE IF EXISTS team_highlights_cache;
DROP TABLE IF EXISTS team_youtube_playlists;
DROP TABLE IF EXISTS team_youtube_sources;

CREATE TABLE team_youtube_sources (
    team_id BIGINT NOT NULL,
    team_name VARCHAR(255) NOT NULL,
    channel_id VARCHAR(255) NOT NULL,
    channel_url VARCHAR(500) NULL,
    source_mode VARCHAR(50) NOT NULL,
    include_title_keywords TEXT NULL,
    exclude_title_keywords TEXT NULL,
    max_candidate_items INT NOT NULL DEFAULT 40,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NULL,
    updated_at DATETIME NULL,
    PRIMARY KEY (team_id)
);

CREATE TABLE team_youtube_playlists (
    id BIGINT NOT NULL AUTO_INCREMENT,
    team_id BIGINT NOT NULL,
    playlist_name VARCHAR(255) NULL,
    playlist_id VARCHAR(255) NOT NULL,
    playlist_url VARCHAR(500) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NULL,
    updated_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_team_playlist (team_id, playlist_id)
);

CREATE TABLE team_highlights_cache (
    id BIGINT NOT NULL AUTO_INCREMENT,
    team_id BIGINT NOT NULL,
    video_id VARCHAR(50) NOT NULL,
    video_url VARCHAR(500) NOT NULL,
    title VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500) NULL,
    published_at DATETIME NULL,
    source_type VARCHAR(50) NOT NULL,
    source_ref VARCHAR(255) NULL,
    rank_order INT NOT NULL,
    created_at DATETIME NULL,
    updated_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_team_video (team_id, video_id),
    UNIQUE KEY uq_team_rank (team_id, rank_order)
);