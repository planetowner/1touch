-- 원래 이름과 세 글자 코드를 유지하고, 화면용 짧은 이름만 따로 저장해요.
ALTER TABLE teams ADD COLUMN short_name VARCHAR(64) NULL AFTER name;
