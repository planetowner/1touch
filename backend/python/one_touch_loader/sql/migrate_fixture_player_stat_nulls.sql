-- 원본의 명시적인 null을 보존해, 생략된 0회와 미제공 값을 구분해요.
ALTER TABLE fixture_player_stats MODIFY COLUMN stat_value DECIMAL(12,4) NULL;
