-- 한 기사가 여러 팀을 다뤄도 기사 정보는 한 번만 저장해요.
CREATE TABLE IF NOT EXISTS news_sources (
    source_key VARCHAR(100) NOT NULL PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    language VARCHAR(2) NOT NULL,
    competition_ids JSON NOT NULL,
    feed_url VARCHAR(2048) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 0,
    last_checked_at DATETIME(6) NULL,
    last_success_at DATETIME(6) NULL,
    last_error VARCHAR(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS news_articles (
    article_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    source_key VARCHAR(100) NOT NULL,
    language VARCHAR(2) NOT NULL,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    url_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    image_url TEXT NULL,
    published_at DATETIME(6) NOT NULL,
    collected_at DATETIME(6) NOT NULL,
    UNIQUE KEY uq_news_url (url_hash),
    KEY idx_news_language_published (language, published_at),
    CONSTRAINT fk_news_source FOREIGN KEY (source_key) REFERENCES news_sources(source_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS news_article_teams (
    article_id BIGINT UNSIGNED NOT NULL,
    team_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (article_id, team_id),
    KEY idx_news_team (team_id, article_id),
    CONSTRAINT fk_news_article FOREIGN KEY (article_id) REFERENCES news_articles(article_id) ON DELETE CASCADE,
    CONSTRAINT fk_news_team FOREIGN KEY (team_id) REFERENCES teams(team_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
