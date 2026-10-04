-- 감독과 연결된 선수의 번역만 저장하고, 미제공 이름은 NULL로 남겨요.
ALTER TABLE coaches
    ADD COLUMN name_ja VARCHAR(255) NULL,
    ADD COLUMN name_zh VARCHAR(255) NULL;
