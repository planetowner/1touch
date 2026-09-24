-- 팀·선수의 언어 접미사와 competitions.name_ko의 길이·정렬 규칙에 맞춰요.
ALTER TABLE competitions
  ADD COLUMN name_ja VARCHAR(120)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  ADD COLUMN name_zh VARCHAR(120)
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL;

-- 2026-09-23에 확인하고 합의한 일본어·중국어 간체 표시명을 저장해요.
START TRANSACTION;

UPDATE competitions AS c
JOIN (
  SELECT 2 AS competition_id,
    'UEFAチャンピオンズリーグ' AS name_ja, '欧洲冠军联赛' AS name_zh
  UNION ALL SELECT 5, 'UEFAヨーロッパリーグ', '欧罗巴联赛'
  UNION ALL SELECT 8, 'プレミアリーグ', '英超联赛'
  UNION ALL SELECT 24, 'FAカップ', '足总杯'
  UNION ALL SELECT 27, 'カラバオカップ', '卡拉宝杯'
  UNION ALL SELECT 82, 'ブンデスリーガ', '德甲联赛'
  UNION ALL SELECT 301, 'リーグ・アン', '法甲联赛'
  UNION ALL SELECT 384, 'セリエA', '意甲联赛'
  UNION ALL SELECT 390, 'コッパ・イタリア', '意大利杯'
  UNION ALL SELECT 564, 'ラ・リーガ', '西甲联赛'
  UNION ALL SELECT 570, 'コパ・デル・レイ', '国王杯'
  UNION ALL SELECT 2286, 'UEFAカンファレンスリーグ', '欧洲协会联赛'
) AS names ON names.competition_id = c.competition_id
SET c.name_ja = names.name_ja,
    c.name_zh = names.name_zh;

COMMIT;

SELECT competition_id, name, name_ko, name_ja, name_zh, short_code
FROM competitions
ORDER BY competition_id;
