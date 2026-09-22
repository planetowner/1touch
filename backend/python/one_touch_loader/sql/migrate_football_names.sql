-- 공급자 적재가 영문 이름을 갱신해도 한국어 표기는 유지해요.
ALTER TABLE teams ADD COLUMN name_ko VARCHAR(160) NULL;
ALTER TABLE players ADD COLUMN display_name_ko VARCHAR(255) NULL;
