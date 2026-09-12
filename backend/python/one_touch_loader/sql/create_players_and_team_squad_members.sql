CREATE TABLE IF NOT EXISTS positions (
  position_id         INT UNSIGNED NOT NULL,
  position_code       VARCHAR(10) NOT NULL,
  position_group_id   INT UNSIGNED NOT NULL,
  position_group_code VARCHAR(10) NOT NULL,

  PRIMARY KEY (position_id),
  UNIQUE KEY uq_positions_code (position_code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


INSERT INTO positions (
  position_id,
  position_code,
  position_group_id,
  position_group_code
) VALUES
  (24,  'GK', 24, 'GK'),
  (148, 'CB', 25, 'DF'),
  (149, 'DM', 26, 'MF'),
  (150, 'AM', 26, 'MF'),
  (151, 'ST', 27, 'FW'),
  (152, 'LW', 27, 'FW'),
  (153, 'CM', 26, 'MF'),
  (154, 'RB', 25, 'DF'),
  (155, 'LB', 25, 'DF'),
  (156, 'RW', 27, 'FW'),
  (157, 'LM', 26, 'MF'),
  (158, 'RM', 26, 'MF'),
  (163, 'SS', 27, 'FW')
ON DUPLICATE KEY UPDATE
  position_code       = VALUES(position_code),
  position_group_id   = VALUES(position_group_id),
  position_group_code = VALUES(position_group_code);


CREATE TABLE IF NOT EXISTS countries (
  country_id BIGINT UNSIGNED NOT NULL,
  name       VARCHAR(120) NOT NULL,
  image_path VARCHAR(512) NULL,

  PRIMARY KEY (country_id)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE IF NOT EXISTS players (
  player_id      BIGINT UNSIGNED NOT NULL,
  display_name   VARCHAR(255) NOT NULL,
  full_name      VARCHAR(255) NOT NULL,
  position_id    INT UNSIGNED NULL,
  nationality_id BIGINT UNSIGNED NULL,
  date_of_birth  DATE NULL,
  height_cm      SMALLINT UNSIGNED NULL,
  weight_kg      SMALLINT UNSIGNED NULL,
  image_path     VARCHAR(512) NULL,

  PRIMARY KEY (player_id),
  KEY idx_players_position (position_id),
  KEY idx_players_nationality (nationality_id),

  CONSTRAINT fk_players_position
    FOREIGN KEY (position_id) REFERENCES positions(position_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_players_nationality
    FOREIGN KEY (nationality_id) REFERENCES countries(country_id)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE IF NOT EXISTS player_external_ids (
  player_id          BIGINT UNSIGNED NOT NULL,
  provider           VARCHAR(50) NOT NULL,
  external_player_id VARCHAR(100) COLLATE utf8mb4_bin NOT NULL,

  PRIMARY KEY (provider, external_player_id),
  UNIQUE KEY uq_player_external_provider (player_id, provider),

  CONSTRAINT fk_player_external_ids_player
    FOREIGN KEY (player_id) REFERENCES players(player_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;


-- 현재 players.player_id는 Sportmonks에서 직접 가져오므로 정확히 연결돼요.
INSERT INTO player_external_ids (player_id, provider, external_player_id)
SELECT player_id, 'sportmonks', CAST(player_id AS CHAR)
FROM players
ON DUPLICATE KEY UPDATE
  external_player_id = VALUES(external_player_id);


CREATE TABLE IF NOT EXISTS team_squad_members (
  team_id           BIGINT UNSIGNED NOT NULL,
  season_id         BIGINT UNSIGNED NOT NULL,
  player_id         BIGINT UNSIGNED NOT NULL,
  position_group_id INT UNSIGNED NULL
    COMMENT 'Sportmonks position_id: 24 GK, 25 DF, 26 MF, 27 FW',
  jersey_number     SMALLINT UNSIGNED NULL,
  squad_role        ENUM(
    'crucial',
    'important',
    'rotation',
    'sporadic',
    'prospect'
  ) NULL COMMENT 'Calculated by 1Touch; not provided by Sportmonks',
  leadership_role   ENUM('captain', 'vice_captain') NULL
    COMMENT 'Manually maintained by 1Touch; not provided by Sportmonks',

  PRIMARY KEY (team_id, season_id, player_id),
  KEY idx_team_squad_player (player_id),
  KEY idx_team_squad_season (season_id),
  UNIQUE KEY uq_team_squad_leadership_role (
    team_id,
    season_id,
    leadership_role
  ),

  CONSTRAINT fk_team_squad_team
    FOREIGN KEY (team_id) REFERENCES teams(team_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_team_squad_season
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_team_squad_player
    FOREIGN KEY (player_id) REFERENCES players(player_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT chk_team_squad_position_group
    CHECK (
      position_group_id IS NULL
      OR position_group_id IN (24, 25, 26, 27)
    )
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;
