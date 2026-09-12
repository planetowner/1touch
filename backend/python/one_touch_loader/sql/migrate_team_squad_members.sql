-- 기존 행은 현재 자국 리그 스쿼드를 뜻해요. 키를 바꾸기 전에 각 행을
-- 해당 팀의 유일한 현재 Big 5 자국 리그 시즌에 연결해요.
ALTER TABLE team_squad_members
  ADD COLUMN season_id BIGINT UNSIGNED NULL AFTER team_id,
  ADD COLUMN position_group_id INT UNSIGNED NULL AFTER player_id,
  ADD COLUMN jersey_number SMALLINT UNSIGNED NULL AFTER position_group_id,
  ADD COLUMN squad_role ENUM(
    'crucial',
    'important',
    'rotation',
    'sporadic',
    'prospect'
  ) NULL COMMENT 'Calculated by 1Touch; not provided by Sportmonks'
    AFTER jersey_number,
  ADD COLUMN leadership_role ENUM('captain', 'vice_captain') NULL
    COMMENT 'Manually maintained by 1Touch; not provided by Sportmonks'
    AFTER squad_role;

UPDATE team_squad_members AS squad
JOIN team_seasons
  ON team_seasons.team_id = squad.team_id
JOIN seasons
  ON seasons.season_id = team_seasons.season_id
JOIN competitions
  ON competitions.competition_id = seasons.competition_id
SET squad.season_id = team_seasons.season_id
WHERE seasons.is_current = 1
  AND competitions.competition_type = 'league';

UPDATE team_squad_members AS squad
JOIN players
  ON players.player_id = squad.player_id
JOIN positions
  ON positions.position_id = players.position_id
SET squad.position_group_id = positions.position_group_id;

ALTER TABLE team_squad_members
  MODIFY COLUMN season_id BIGINT UNSIGNED NOT NULL AFTER team_id,
  MODIFY COLUMN position_group_id INT UNSIGNED NULL
    COMMENT 'Sportmonks position_id: 24 GK, 25 DF, 26 MF, 27 FW'
    AFTER player_id,
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (team_id, season_id, player_id),
  ADD KEY idx_team_squad_season (season_id),
  ADD UNIQUE KEY uq_team_squad_leadership_role (
    team_id,
    season_id,
    leadership_role
  ),
  ADD CONSTRAINT fk_team_squad_season
    FOREIGN KEY (season_id) REFERENCES seasons(season_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  ADD CONSTRAINT chk_team_squad_position_group
    CHECK (
      position_group_id IS NULL
      OR position_group_id IN (24, 25, 26, 27)
    );

SELECT
  column_name,
  column_type,
  is_nullable,
  column_comment
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'team_squad_members'
ORDER BY ordinal_position;

SELECT
  index_name,
  GROUP_CONCAT(column_name ORDER BY seq_in_index) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'team_squad_members'
GROUP BY index_name
ORDER BY index_name;

SELECT
  constraint_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND table_name = 'team_squad_members'
  AND referenced_table_name IS NOT NULL
ORDER BY constraint_name, ordinal_position;

SELECT
  team_id,
  season_id,
  COUNT(*) AS squad_members,
  SUM(position_group_id IS NULL) AS missing_position_groups,
  SUM(jersey_number IS NULL) AS missing_jersey_numbers,
  SUM(squad_role IS NOT NULL) AS calculated_squad_roles,
  SUM(leadership_role IS NOT NULL) AS manual_leadership_roles
FROM team_squad_members
GROUP BY team_id, season_id
ORDER BY team_id, season_id;
