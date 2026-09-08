-- migrate_leagues_to_competitions.sql 전에 이 읽기 전용 점검을 실행하세요.
-- 첫 결과에는 이전 스키마가 정확히 한 번 나와야 해요.
SELECT
  (SELECT COUNT(*)
   FROM information_schema.tables
   WHERE table_schema = DATABASE() AND table_name = 'leagues') AS leagues_tables,
  (SELECT COUNT(*)
   FROM information_schema.tables
   WHERE table_schema = DATABASE() AND table_name = 'competitions') AS competitions_tables,
  (SELECT COUNT(*)
   FROM information_schema.columns
   WHERE table_schema = DATABASE()
     AND table_name = 'fixtures'
     AND column_name = 'competition_type') AS fixture_competition_type_columns;

-- 행을 하나도 반환하면 안 돼요. 한 대회에 서로 다른 type이 있을 수 없어요.
SELECT
  l.league_id,
  l.name,
  COUNT(DISTINCT f.competition_type) AS distinct_competition_types,
  GROUP_CONCAT(DISTINCT f.competition_type ORDER BY f.competition_type) AS competition_types
FROM leagues l
LEFT JOIN fixtures f ON f.league_id = l.league_id
GROUP BY l.league_id, l.name
HAVING COUNT(DISTINCT f.competition_type) <> 1;

-- 실제로 leagues를 가리키는 운영 외래 키를 보여줘요. 마이그레이션은 과거 스키마
-- 스냅샷이 아니라 여기 나온 제약 조건만 정확히 삭제해야 해요.
SELECT
  kcu.constraint_name,
  kcu.table_name,
  kcu.column_name,
  kcu.referenced_table_name,
  kcu.referenced_column_name
FROM information_schema.key_column_usage kcu
WHERE kcu.constraint_schema = DATABASE()
  AND kcu.referenced_table_name = 'leagues'
ORDER BY kcu.table_name, kcu.constraint_name, kcu.ordinal_position;

-- 이름을 바꿀 모든 내부 이전 열을 보여줘요.
SELECT table_name, column_name, column_type
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND column_name IN ('league_id', 'league_name', 'league_image_path')
ORDER BY table_name, ordinal_position;

-- league_id가 들어간 모든 운영 인덱스를 보여줘요. 실제로 이전할 데이터베이스와
-- 인덱스 이름 변경 대상을 맞출 수 있어요.
SELECT
  table_name,
  index_name,
  GROUP_CONCAT(column_name ORDER BY seq_in_index) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
GROUP BY table_name, index_name
HAVING FIND_IN_SET('league_id', indexed_columns) > 0
ORDER BY table_name, index_name;
