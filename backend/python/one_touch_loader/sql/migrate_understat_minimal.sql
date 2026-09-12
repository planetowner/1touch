-- 실행 전 run_understat_migration.ps1로 기존 빈 테이블과 백업을 확인해요.
-- 공급자 ID는 Capology와 같은 외부 ID 테이블 계약을 사용해요.
CREATE TABLE fixture_external_ids (
  fixture_id BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(50) NOT NULL,
  external_fixture_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (provider, external_fixture_id),
  UNIQUE KEY uq_fixture_external_provider (fixture_id, provider),
  CONSTRAINT fk_fixture_external_ids_fixture FOREIGN KEY (fixture_id)
    REFERENCES fixtures(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 팀 ID는 fixtures의 홈·원정 관계로 알아요. xGA는 상대 xG라 별도 저장하지 않아요.
CREATE TABLE fixture_expected_goals (
  fixture_id BIGINT UNSIGNED NOT NULL,
  home_xg DECIMAL(10,6) NOT NULL,
  away_xg DECIMAL(10,6) NOT NULL,
  PRIMARY KEY (fixture_id),
  CONSTRAINT fk_fixture_expected_goals_fixture FOREIGN KEY (fixture_id)
    REFERENCES fixtures(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 원본이 제공한 0과 미제공을 구분하려고 선수 명단의 xG를 직접 저장해요.
CREATE TABLE fixture_player_expected_goals (
  fixture_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  xg DECIMAL(10,6) NOT NULL,
  PRIMARY KEY (fixture_id, player_id),
  CONSTRAINT fk_fixture_player_xg_fixture FOREIGN KEY (fixture_id)
    REFERENCES fixtures(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_player_xg_player FOREIGN KEY (player_id)
    REFERENCES players(player_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- shot_id는 Understat 원본 ID예요. 좌표는 정규화된 시작 위치만 저장해요.
CREATE TABLE fixture_shots (
  shot_id BIGINT UNSIGNED NOT NULL,
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  minute SMALLINT UNSIGNED NOT NULL,
  x DECIMAL(10,9) NOT NULL,
  y DECIMAL(10,9) NOT NULL,
  xg DECIMAL(10,6) NOT NULL,
  result VARCHAR(20) NOT NULL,
  PRIMARY KEY (shot_id),
  KEY idx_fixture_shots_fixture (fixture_id),
  CONSTRAINT fk_fixture_shots_fixture FOREIGN KEY (fixture_id)
    REFERENCES fixtures(fixture_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_shots_team FOREIGN KEY (team_id)
    REFERENCES teams(team_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_shots_player FOREIGN KEY (player_id)
    REFERENCES players(player_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 현재 리그 설정 5행 외에는 빈 초안 테이블이에요. 변환은 코드의 고정 규칙을 사용해요.
DROP TABLE understat_team_map;
DROP TABLE understat_season_map;
DROP TABLE understat_league_map;
DROP TABLE xg_standings;
DROP TABLE xg_standings_calibration;

-- 순위 화면의 시즌별 집계 결과예요. 대회는 seasons 관계로 조회해요.
CREATE TABLE xg_standings (
  season_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  position SMALLINT UNSIGNED NOT NULL,
  matches_played SMALLINT UNSIGNED NOT NULL,
  xg DECIMAL(10,3) NOT NULL,
  xga DECIMAL(10,3) NOT NULL,
  xpts DECIMAL(8,2) NOT NULL,
  PRIMARY KEY (season_id, team_id),
  CONSTRAINT fk_xg_standings_season FOREIGN KEY (season_id)
    REFERENCES seasons(season_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_xg_standings_team FOREIGN KEY (team_id)
    REFERENCES teams(team_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 기존 xPts 알고리즘의 무승부 경계와 계산 근거만 보존해요.
CREATE TABLE xg_standings_calibration (
  season_id BIGINT UNSIGNED NOT NULL,
  calibration_match_count INT UNSIGNED NOT NULL,
  target_draw_rate DECIMAL(7,6) NOT NULL,
  draw_band DECIMAL(10,3) NOT NULL,
  PRIMARY KEY (season_id),
  CONSTRAINT fk_xg_calibration_season FOREIGN KEY (season_id)
    REFERENCES seasons(season_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
