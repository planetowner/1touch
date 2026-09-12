SELECT
    COUNT(*) AS capology_player_ids_before,
    COALESCE(SUM(external_player_id REGEXP '^[0-9]+$'), 0) AS numeric_only_ids_before,
    COALESCE(SUM(external_player_id REGEXP '^[a-z0-9-]+-[0-9]+$'), 0) AS full_ids_before
FROM player_external_ids
WHERE provider = 'capology';

START TRANSACTION;

-- 숫자 접미사는 선수마다 고유하지 않으므로 기존 Capology 매핑을 다시 수집해야 해요.
DELETE FROM player_external_ids
WHERE provider = 'capology';

SELECT ROW_COUNT() AS deleted_capology_player_ids;

COMMIT;

SELECT COUNT(*) AS capology_player_ids_after
FROM player_external_ids
WHERE provider = 'capology';
