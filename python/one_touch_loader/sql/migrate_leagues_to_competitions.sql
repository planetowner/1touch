-- 2026-08-08에 migrate_leagues_to_competitions_preflight.sql로 확인한
-- 운영 스키마의 호환되지 않는 이름 변경이에요.
--
-- MySQL DDL은 자동으로 커밋돼요. 이 파일을 적용하기 전에 백엔드를 멈추고
-- 데이터베이스를 백업하세요.

-- fixtures의 중복 열을 없애기 전에 type을 소유 테이블로 옮겨요.
ALTER TABLE leagues
  ADD COLUMN competition_type ENUM('league','europe','domestic_cup') NULL
  AFTER image_path;

UPDATE leagues l
JOIN (
  SELECT league_id, MIN(competition_type) AS competition_type
  FROM fixtures
  GROUP BY league_id
) fixture_types ON fixture_types.league_id = l.league_id
SET l.competition_type = fixture_types.competition_type;

ALTER TABLE leagues
  MODIFY COLUMN competition_type ENUM('league','europe','domestic_cup') NOT NULL;

-- 이 뷰는 team_attribute_group_scores.league_id를 공개해요. 기본 열 이름을 바꾼 뒤
-- 외부 필드가 competition_id가 되도록 다시 만들어요.
DROP VIEW IF EXISTS v_team_attribute_display_scores;

-- 현재 leagues를 가리키는 운영 외래 키 6개만 정확히 삭제해요.
ALTER TABLE fixture_team_stats_raw DROP FOREIGN KEY fk_ftsr_league;
ALTER TABLE fixtures DROP FOREIGN KEY fk_fixtures_league;
ALTER TABLE seasons DROP FOREIGN KEY fk_seasons_league;
ALTER TABLE understat_league_map DROP FOREIGN KEY fk_understat_league_map_league;
ALTER TABLE xg_standings DROP FOREIGN KEY fk_xg_standings_league;
ALTER TABLE xg_standings_calibration DROP FOREIGN KEY fk_xg_stand_calib_league;

RENAME TABLE leagues TO competitions;
ALTER TABLE competitions RENAME COLUMN league_id TO competition_id;

ALTER TABLE fixture_team_stats_raw RENAME COLUMN league_id TO competition_id;
ALTER TABLE fixtures RENAME COLUMN league_id TO competition_id;
ALTER TABLE knockout_ties RENAME COLUMN league_id TO competition_id;
ALTER TABLE player_team_honours RENAME COLUMN league_id TO competition_id;
ALTER TABLE seasons RENAME COLUMN league_id TO competition_id;
ALTER TABLE stage_groups RENAME COLUMN league_id TO competition_id;
ALTER TABLE stages RENAME COLUMN league_id TO competition_id;
ALTER TABLE standings RENAME COLUMN league_id TO competition_id;
ALTER TABLE team_attribute_group_scores RENAME COLUMN league_id TO competition_id;
ALTER TABLE team_attribute_training_features RENAME COLUMN league_id TO competition_id;
ALTER TABLE team_seasons RENAME COLUMN league_id TO competition_id;
ALTER TABLE xg_standings RENAME COLUMN league_id TO competition_id;
ALTER TABLE xg_standings_calibration RENAME COLUMN league_id TO competition_id;

ALTER TABLE fixtures DROP COLUMN competition_type;

-- 내부 이름에 league가 남은 운영 인덱스만 바꿔요.
-- 기본 키와 고유 인덱스는 기존의 일반 이름을 유지해요.
ALTER TABLE fixture_team_stats_raw
  RENAME INDEX fk_ftsr_league TO idx_ftsr_competition,
  RENAME INDEX idx_ftsr_season_league TO idx_ftsr_season_competition;
ALTER TABLE fixtures
  RENAME INDEX idx_fixtures_season_league_time
  TO idx_fixtures_season_competition_time;
ALTER TABLE player_team_honours
  RENAME INDEX idx_player_team_honours_league
  TO idx_player_team_honours_competition;
ALTER TABLE seasons
  RENAME INDEX idx_seasons_league TO idx_seasons_competition;
ALTER TABLE stage_groups
  RENAME INDEX idx_group_l_s TO idx_stage_groups_competition_season;
ALTER TABLE stages
  RENAME INDEX idx_stage_l_s TO idx_stages_competition_season_type;
ALTER TABLE team_attribute_group_scores
  RENAME INDEX idx_team_attribute_group_scores_league_season
  TO idx_team_attribute_group_scores_competition_season;
ALTER TABLE team_attribute_training_features
  RENAME INDEX idx_team_attribute_training_features_league_season
  TO idx_team_attribute_training_features_competition_season;
ALTER TABLE team_seasons
  RENAME INDEX idx_ts_league_season TO idx_ts_competition_season;

-- 이름을 바꾸기 전에 있던 관계 6개만 다시 만들어요.
ALTER TABLE fixture_team_stats_raw
  ADD CONSTRAINT fk_ftsr_competition
  FOREIGN KEY (competition_id) REFERENCES competitions(competition_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE fixtures
  ADD CONSTRAINT fk_fixtures_competition
  FOREIGN KEY (competition_id) REFERENCES competitions(competition_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE seasons
  ADD CONSTRAINT fk_seasons_competition
  FOREIGN KEY (competition_id) REFERENCES competitions(competition_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE understat_league_map
  ADD CONSTRAINT fk_understat_league_map_competition
-- Sportmonks의 공급자 필드 이름은 league_id예요. 내부에서는
-- competitions.competition_id를 참조해요.
  FOREIGN KEY (sportmonks_league_id) REFERENCES competitions(competition_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE xg_standings
  ADD CONSTRAINT fk_xg_standings_competition
  FOREIGN KEY (competition_id) REFERENCES competitions(competition_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE xg_standings_calibration
  ADD CONSTRAINT fk_xg_stand_calib_competition
  FOREIGN KEY (competition_id) REFERENCES competitions(competition_id)
  ON DELETE RESTRICT ON UPDATE CASCADE;

UPDATE team_attribute_regression_models
SET normalization_scope = 'competition_season_zscore'
WHERE normalization_scope = 'league_season_zscore';

CREATE VIEW v_team_attribute_display_scores AS
SELECT
  s.model_id,
  s.competition_id,
  s.season_id,
  s.team_id,
  t.name AS team_name,
  ROUND(MAX(CASE WHEN s.attribute_group = 'possession_build_up'
    THEN s.display_score_0_100 END), 2) AS possession_build_up,
  ROUND(MAX(CASE WHEN s.attribute_group = 'attacking_threat'
    THEN s.display_score_0_100 END), 2) AS attacking_threat,
  ROUND(MAX(CASE WHEN s.attribute_group = 'chance_creation'
    THEN s.display_score_0_100 END), 2) AS chance_creation,
  ROUND(MAX(CASE WHEN s.attribute_group = 'finishing'
    THEN s.display_score_0_100 END), 2) AS finishing,
  ROUND(MAX(CASE WHEN s.attribute_group = 'defending'
    THEN s.display_score_0_100 END), 2) AS defending,
  MAX(s.updated_at) AS attributes_updated_at
FROM team_attribute_group_scores s
JOIN team_attribute_regression_models m
  ON m.id = s.model_id
 AND m.is_active = 1
LEFT JOIN teams t ON t.team_id = s.team_id
GROUP BY
  s.model_id,
  s.competition_id,
  s.season_id,
  s.team_id,
  t.name;

-- 확인: 첫 쿼리는 행을 하나도 반환하면 안 돼요. sportmonks_league_id와
-- understat_league_key처럼 공급자에 종속된 이름은 의도적으로 유지해요.
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND (
    table_name = 'leagues'
    OR column_name IN ('league_id', 'league_name', 'league_image_path')
  )
ORDER BY table_name, ordinal_position;

SELECT competition_id, name, competition_type
FROM competitions
ORDER BY competition_id;

SELECT
  kcu.constraint_name,
  kcu.table_name,
  kcu.column_name,
  kcu.referenced_table_name,
  kcu.referenced_column_name
FROM information_schema.key_column_usage kcu
WHERE kcu.constraint_schema = DATABASE()
  AND kcu.referenced_table_name = 'competitions'
ORDER BY kcu.table_name, kcu.constraint_name;
