-- 기존 영문·한국어와 구분해 공급자가 반환한 표시 이름만 저장해요.
ALTER TABLE teams ADD COLUMN name_ja VARCHAR(160) NULL, ADD COLUMN name_zh VARCHAR(160) NULL;
ALTER TABLE players ADD COLUMN display_name_ja VARCHAR(255) NULL, ADD COLUMN display_name_zh VARCHAR(255) NULL;
