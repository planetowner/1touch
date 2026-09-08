-- 실행 스크립트가 기존 세 테이블이 비어 있는지 확인하고 전체 DB를 백업해요.
DROP TABLE fixture_team_stats_raw;
DROP TABLE fixture_lineups;
DROP TABLE fixture_formations;

CREATE TABLE fixture_event_types (
  event_type_id INT NOT NULL,
  code VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (event_type_id),
  UNIQUE KEY uq_fixture_event_types_code (code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_stat_types (
  stat_type_id INT NOT NULL,
  code VARCHAR(100) NOT NULL,
  name VARCHAR(100) NOT NULL,
  PRIMARY KEY (stat_type_id),
  UNIQUE KEY uq_fixture_stat_types_code (code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE coaches (
  coach_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  PRIMARY KEY (coach_id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_events (
  event_id BIGINT UNSIGNED NOT NULL,
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  event_type_id INT NOT NULL,
  player_id BIGINT UNSIGNED NULL,
  related_player_id BIGINT UNSIGNED NULL,
  minute SMALLINT UNSIGNED NOT NULL,
  extra_minute SMALLINT UNSIGNED NULL,
  on_bench BOOLEAN NULL,
  PRIMARY KEY (event_id),
  KEY idx_fixture_events_fixture_minute (fixture_id, minute, extra_minute),
  KEY idx_fixture_events_team (team_id),
  KEY idx_fixture_events_type (event_type_id),
  KEY idx_fixture_events_player (player_id),
  KEY idx_fixture_events_related_player (related_player_id),
  CONSTRAINT fk_fixture_events_fixture
    FOREIGN KEY (fixture_id) REFERENCES fixtures (fixture_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_events_team
    FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_events_type
    FOREIGN KEY (event_type_id) REFERENCES fixture_event_types (event_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_events_player
    FOREIGN KEY (player_id) REFERENCES players (player_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_events_related_player
    FOREIGN KEY (related_player_id) REFERENCES players (player_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_team_stats (
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  stat_type_id INT NOT NULL,
  stat_value DECIMAL(12,4) NOT NULL,
  PRIMARY KEY (fixture_id, team_id, stat_type_id),
  KEY idx_fixture_team_stats_team (team_id),
  KEY idx_fixture_team_stats_type (stat_type_id),
  CONSTRAINT fk_fixture_team_stats_fixture
    FOREIGN KEY (fixture_id) REFERENCES fixtures (fixture_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_team_stats_team
    FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_team_stats_type
    FOREIGN KEY (stat_type_id) REFERENCES fixture_stat_types (stat_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_lineups (
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  player_id BIGINT UNSIGNED NOT NULL,
  lineup_type_id INT NOT NULL,
  formation_field VARCHAR(10) NULL,
  jersey_number SMALLINT UNSIGNED NULL,
  minutes_played SMALLINT UNSIGNED NULL,
  rating DECIMAL(4,2) NULL,
  PRIMARY KEY (fixture_id, team_id, player_id),
  KEY idx_fixture_lineups_team (team_id),
  KEY idx_fixture_lineups_player (player_id),
  CONSTRAINT fk_fixture_lineups_fixture
    FOREIGN KEY (fixture_id) REFERENCES fixtures (fixture_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_lineups_team
    FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_lineups_player
    FOREIGN KEY (player_id) REFERENCES players (player_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_formations (
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  formation VARCHAR(20) NOT NULL,
  PRIMARY KEY (fixture_id, team_id),
  KEY idx_fixture_formations_team (team_id),
  CONSTRAINT fk_fixture_formations_fixture
    FOREIGN KEY (fixture_id) REFERENCES fixtures (fixture_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_formations_team
    FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_coaches (
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  coach_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (fixture_id, team_id),
  KEY idx_fixture_coaches_team (team_id),
  KEY idx_fixture_coaches_coach (coach_id),
  CONSTRAINT fk_fixture_coaches_fixture
    FOREIGN KEY (fixture_id) REFERENCES fixtures (fixture_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_coaches_team
    FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_coaches_coach
    FOREIGN KEY (coach_id) REFERENCES coaches (coach_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE fixture_pressures (
  fixture_id BIGINT UNSIGNED NOT NULL,
  team_id BIGINT UNSIGNED NOT NULL,
  minute SMALLINT UNSIGNED NOT NULL,
  pressure DECIMAL(6,2) NOT NULL,
  PRIMARY KEY (fixture_id, team_id, minute),
  KEY idx_fixture_pressures_team (team_id),
  CONSTRAINT fk_fixture_pressures_fixture
    FOREIGN KEY (fixture_id) REFERENCES fixtures (fixture_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_fixture_pressures_team
    FOREIGN KEY (team_id) REFERENCES teams (team_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
