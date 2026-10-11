-- 기존 이벤트는 부상 여부를 수집하지 않았으므로 false 대신 null로 남겨요.
ALTER TABLE fixture_events ADD COLUMN injured BOOLEAN NULL;
