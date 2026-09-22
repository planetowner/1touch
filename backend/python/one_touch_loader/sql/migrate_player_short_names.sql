-- 일반 표시 이름을 유지하고 좁은 화면에 쓸 표기를 별도로 저장해요.
ALTER TABLE players
  ADD COLUMN short_name VARCHAR(255) NULL,
  ADD COLUMN short_name_ko VARCHAR(255) NULL,
  ADD COLUMN short_name_ja VARCHAR(255) NULL,
  ADD COLUMN short_name_zh VARCHAR(255) NULL;
