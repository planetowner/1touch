-- 기존 제재는 사유가 기록되지 않았으므로 NULL로 남겨요.
ALTER TABLE users ADD COLUMN suspension_reason VARCHAR(32) NULL;
