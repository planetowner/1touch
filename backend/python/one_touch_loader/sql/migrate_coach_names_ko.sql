-- 공급자 적재가 원문 이름을 갱신해도 한국어 표기는 유지해요.
ALTER TABLE coaches ADD COLUMN name_ko VARCHAR(255) NULL;
