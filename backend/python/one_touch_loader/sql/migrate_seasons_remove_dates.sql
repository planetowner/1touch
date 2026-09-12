-- seasons.name의 YYYY/YYYY 값을 시즌 시간 순서의 기준으로 써요.
-- 이 마이그레이션 전에 기존 104개 행을 확인했어요.
ALTER TABLE seasons
  DROP COLUMN starting_at,
  DROP COLUMN ending_at;

SELECT column_name, column_type, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'seasons'
ORDER BY ordinal_position;
