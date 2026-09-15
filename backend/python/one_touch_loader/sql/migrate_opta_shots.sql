-- Understat의 fixture_shots·xG 테이블은 보존해요. Opta의 유효슈팅 좌표만 추가해요.
-- 수집 완료 행이 있어야 0개 경기와 아직 수집하지 않은 경기를 구분할 수 있어요.
CREATE TABLE fixture_opta_shotmaps (
  fixture_id BIGINT UNSIGNED NOT NULL,
  external_fixture_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  external_competition_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  external_season_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  source_url VARCHAR(1000) NOT NULL,
  home_count SMALLINT UNSIGNED NOT NULL,
  away_count SMALLINT UNSIGNED NOT NULL,
  collected_at DATETIME(6) NOT NULL COMMENT 'UTC 수집 시각',
  PRIMARY KEY (fixture_id),
  UNIQUE KEY uq_opta_shotmap_external (external_fixture_id),
  CONSTRAINT fk_opta_shotmap_fixture FOREIGN KEY (fixture_id)
    REFERENCES fixtures(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_opta_shots (
  external_event_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  minute SMALLINT UNSIGNED NOT NULL,
  extra_minute SMALLINT UNSIGNED NOT NULL,
  result ENUM('goal','on_target') NOT NULL,
  start_x DECIMAL(9,6) NOT NULL,
  start_y DECIMAL(9,6) NOT NULL,
  end_x DECIMAL(9,6) NOT NULL,
  end_y DECIMAL(9,6) NOT NULL,
  PRIMARY KEY (external_event_id),
  KEY idx_opta_shots_fixture (fixture_id, minute, extra_minute),
  CONSTRAINT fk_opta_shot_map FOREIGN KEY (fixture_id)
    REFERENCES fixture_opta_shotmaps(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_opta_shot_team FOREIGN KEY (team_id)
    REFERENCES teams(team_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_opta_shot_player FOREIGN KEY (player_id)
    REFERENCES players(player_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
