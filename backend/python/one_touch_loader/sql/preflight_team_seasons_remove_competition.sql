-- competition_id를 지우기 전에 현재 team_seasons의 구조와 데이터를 확인해요.
SELECT
  column_name,
  column_type,
  is_nullable,
  column_key
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'team_seasons'
ORDER BY ordinal_position;

SELECT
  COUNT(*) AS team_season_rows,
  COUNT(DISTINCT team_id) AS linked_teams,
  COUNT(DISTINCT season_id) AS linked_seasons
FROM team_seasons;

-- 세 결과가 모두 0이어야 team_id와 season_id만 남겨도 기존 관계가 보존돼요.
SELECT
  COALESCE(SUM(CASE WHEN teams.team_id IS NULL THEN 1 ELSE 0 END), 0) AS missing_teams,
  COALESCE(SUM(CASE WHEN seasons.season_id IS NULL THEN 1 ELSE 0 END), 0) AS missing_seasons,
  COALESCE(SUM(
    CASE
      WHEN seasons.season_id IS NOT NULL
       AND team_seasons.competition_id <> seasons.competition_id
      THEN 1
      ELSE 0
    END
  ), 0) AS competition_mismatches
FROM team_seasons
LEFT JOIN teams
  ON teams.team_id = team_seasons.team_id
LEFT JOIN seasons
  ON seasons.season_id = team_seasons.season_id;

-- 행을 반환하면 안 돼요. competition_id를 지운 뒤 중복될 관계를 찾아요.
SELECT
  team_id,
  season_id,
  COUNT(*) AS duplicate_rows
FROM team_seasons
GROUP BY team_id, season_id
HAVING COUNT(*) > 1;

-- 현재 어떤 대회 시즌 관계가 적재돼 있는지 보여줘요.
SELECT
  seasons.competition_id,
  competitions.name AS competition_name,
  COUNT(DISTINCT team_seasons.season_id) AS linked_seasons,
  COUNT(DISTINCT team_seasons.team_id) AS linked_teams,
  COUNT(*) AS membership_rows
FROM team_seasons
JOIN seasons
  ON seasons.season_id = team_seasons.season_id
JOIN competitions
  ON competitions.competition_id = seasons.competition_id
GROUP BY seasons.competition_id, competitions.name
ORDER BY seasons.competition_id;

SELECT
  COUNT(*) AS teams_without_seasons
FROM teams
LEFT JOIN team_seasons
  ON team_seasons.team_id = teams.team_id
WHERE team_seasons.team_id IS NULL;

SELECT
  teams.team_id,
  teams.name
FROM teams
LEFT JOIN team_seasons
  ON team_seasons.team_id = teams.team_id
WHERE team_seasons.team_id IS NULL
ORDER BY teams.name, teams.team_id
LIMIT 30;

-- competition_id와 연결된 실제 인덱스와 외래 키를 확인해요.
SELECT
  index_name,
  GROUP_CONCAT(column_name ORDER BY seq_in_index) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'team_seasons'
GROUP BY index_name
ORDER BY index_name;

SELECT
  constraint_name,
  column_name,
  referenced_table_name,
  referenced_column_name
FROM information_schema.key_column_usage
WHERE constraint_schema = DATABASE()
  AND table_name = 'team_seasons'
ORDER BY constraint_name, ordinal_position;
