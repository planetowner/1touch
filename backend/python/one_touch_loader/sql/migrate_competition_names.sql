-- 2026-09-23에 확인한 스키마를 기준으로 추가해요.
-- 번역 이름은 기존 name 길이에, 약어는 teams.short_code 규칙에 맞춰요.
ALTER TABLE competitions
  ADD COLUMN name_ko VARCHAR(120)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  ADD COLUMN short_code VARCHAR(16)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL;

-- 공급자 원문 name은 유지하고, 합의한 한국어 이름과 약어만 저장해요.
-- 별도 이니셜 약어를 확인하지 못한 대회는 합의한 영문 명칭을 써요.
START TRANSACTION;

UPDATE competitions AS c
JOIN (
  SELECT 2 AS competition_id, 'UEFA 챔피언스리그' AS name_ko, 'UCL' AS short_code
  UNION ALL SELECT 5, 'UEFA 유로파리그', 'UEL'
  UNION ALL SELECT 8, '프리미어리그', 'PL'
  UNION ALL SELECT 24, 'FA컵', 'FA Cup'
  UNION ALL SELECT 27, '카라바오컵', 'EFL Cup'
  UNION ALL SELECT 82, '분데스리가', 'BL'
  UNION ALL SELECT 301, '리그 1', 'L1'
  UNION ALL SELECT 384, '세리에 A', 'Serie A'
  UNION ALL SELECT 390, '코파 이탈리아', 'Coppa Italia'
  UNION ALL SELECT 564, '라리가', 'LALIGA'
  UNION ALL SELECT 570, '코파 델 레이', 'CDR'
  UNION ALL SELECT 2286, 'UEFA 컨퍼런스리그', 'UECL'
) AS names ON names.competition_id = c.competition_id
SET c.name_ko = names.name_ko,
    c.short_code = names.short_code;

COMMIT;

SELECT competition_id, name, name_ko, short_code
FROM competitions
ORDER BY competition_id;
