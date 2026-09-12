-- Sportmonks 선수 단건과 시즌 스쿼드에 상세 포지션이 모두 없을 수 있어요.
-- 일반 포지션이나 경기 배치로 추측하지 않고 확인할 수 없는 값은 NULL로 저장해요.
ALTER TABLE players
  MODIFY COLUMN position_id INT UNSIGNED NULL AFTER full_name;

SELECT
  column_name,
  column_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'players'
  AND column_name = 'position_id';
