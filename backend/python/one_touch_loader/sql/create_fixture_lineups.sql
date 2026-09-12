CREATE TABLE IF NOT EXISTS fixture_lineups (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  fixture_id      BIGINT NOT NULL,
  season_id       BIGINT NOT NULL,
  team_id         BIGINT NOT NULL,
  player_id       BIGINT NOT NULL,
  player_name     VARCHAR(255) NULL,
  player_image    VARCHAR(512) NULL,
  position_id     INT NULL,              -- 24=GK, 25=DF, 26=MF, 27=FW
  position_name   VARCHAR(50) NULL,      -- "Goalkeeper", "Defender", ...
  detailed_position_name VARCHAR(100) NULL, -- "Centre-Back", "Left Winger", ...
  formation_field VARCHAR(10) NULL,      -- "1:1", "2:3" 등 포메이션 내 좌표
  type_id         INT NOT NULL,          -- 11=선발(starter), 12=벤치(bench)
  minutes_played  INT NULL DEFAULT 0,

  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uq_fl_fixture_team_player (fixture_id, team_id, player_id),
  KEY idx_fl_team_season (team_id, season_id),
  KEY idx_fl_fixture (fixture_id)
);
