CREATE TABLE IF NOT EXISTS fixture_formations (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  fixture_id  BIGINT NOT NULL,
  season_id   BIGINT NOT NULL,
  team_id     BIGINT NOT NULL,
  formation   VARCHAR(20) NOT NULL,    -- "4-3-3", "3-5-2" 등

  UNIQUE KEY uq_ff_fixture_team (fixture_id, team_id),
  KEY idx_ff_team_season (team_id, season_id)
);
